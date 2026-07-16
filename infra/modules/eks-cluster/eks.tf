#======================================================================
# EKS 클러스터
#   - 공식 AWS EKS 모듈 v21 기반. 접근제어 / 애드온 / 노드그룹 정의.
#   - v21에서 다수 변수명이 바뀜(cluster_ 접두사 제거 등). 모듈 외부 인터페이스
#     (var.cluster_name 등)는 유지하고 여기서 v21 이름으로 매핑한다.
#======================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name    # v20: cluster_name
  kubernetes_version = var.cluster_version  # v20: cluster_version
  region             = var.aws_region       # v21 신규

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids # 노드는 프라이빗 서브넷에 배치

  # --- 접근 제어 ---
  # 인증 모드: 기본 API_AND_CONFIG_MAP (Access Entry + 레거시 ConfigMap 병행)
  authentication_mode = var.authentication_mode

  # 클러스터 생성자에게 관리자 권한 자동 부여 (Access Entry 방식)
  enable_cluster_creator_admin_permissions = true

  # 생성자 외 추가 멤버 (var.access_entries -> 모듈 형식으로 변환)
  access_entries = {
    for k, v in var.access_entries : k => {
      principal_arn = v.principal_arn
      policy_associations = {
        this = {
          policy_arn = v.policy_arn
          access_scope = {
            type       = length(v.namespaces) > 0 ? "namespace" : "cluster"
            namespaces = v.namespaces
          }
        }
      }
    }
  }

  # --- 엔드포인트 접근 (v20: cluster_endpoint_*) ---
  # 원격에서 kubectl 접근이 가능하도록 퍼블릭 엔드포인트 활성화
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  endpoint_private_access      = true

  # --- KMS / 로그 비활성화 (kms:*, logs:* 권한 불필요하게) ---
  # v21은 encryption_config가 null이어야 암호화가 완전히 꺼진다(기본 {}는 암호화 ON).
  # off -> Secret은 AWS 기본 암호화로 저장됨(평문 아님).
  #   CMK/envelope 암호화를 요구하는 컴플라이언스(PCI-DSS 등)면 켤 것.
  encryption_config = null

  # 로그 off -> 컨트롤플레인 감사로그 미수집. 규제상 감사 추적 필요하면 enabled_log_types 채울 것.
  create_cloudwatch_log_group = false
  enabled_log_types           = [] # v20: cluster_enabled_log_types

  # --- 노드 보안그룹 태그 ---
  # Karpenter가 EC2NodeClass의 securityGroupSelectorTerms로 이 node SG를 찾도록
  # discovery 태그를 붙인다. (merge라 기존 태그는 보존되고 이 태그만 추가됨)
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # --- 관리형 애드온 (v20: cluster_addons) ---
  # 필수(없으면 클러스터 동작 불가): vpc-cni, coredns, kube-proxy
  # 준필수(본 구성 전제): eks-pod-identity-agent, aws-ebs-csi-driver
  # 운영 편의: eks-node-monitoring-agent, metrics-server
  #
  # vpc-cni/ebs-csi의 IAM 역할은 애드온이 소유하는 pod_identity_association으로 연결함.
  # v21은 most_recent 기본 true(항상 최신 애드온) / resolve_conflicts는 자동 처리.
  addons = {
    # Pod Identity 에이전트: association이 실제 작동하려면 필수 전제.
    # before_compute=true -> 노드/CNI보다 먼저 떠서, CNI가 처음부터 자격증명을 받게 함.
    eks-pod-identity-agent = {
      before_compute = true
    }

    # 파드 네트워킹(ENI/IP). before_compute=true로 노드 부팅 전에 준비되게 함.
    # IAM 권한 필요 -> pod_identity_association 필수. standalone이 아닌 애드온 귀속으로 생성.
    vpc-cni = {
      before_compute = true
      pod_identity_association = [{
        role_arn        = aws_iam_role.vpc_cni.arn
        service_account = local.pod_identity_sa.vpc_cni # "aws-node"
      }]
    }

    # 클러스터 내부 DNS
    coredns = {}

    # 서비스 네트워킹(iptables 규칙). 네트워킹 필수 애드온이라 함께 둠.
    kube-proxy = {}

    # 영구 볼륨(EBS) 프로비저닝 드라이버
    # IAM 권한 필요 -> pod_identity_association 필수. standalone이 아닌 애드온 귀속으로 생성.
    aws-ebs-csi-driver = {
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = local.pod_identity_sa.ebs_csi # "ebs-csi-controller-sa"
      }]
    }

    # 노드 상태 모니터링 에이전트
    eks-node-monitoring-agent = {}

    # 지표 서버(HPA/kubectl top용)
    metrics-server = {}
  }

  # EKS Managed Node Groups 설정
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-main"
      # use_name_prefix=true(default)를 명시적으로 둠. 노드그룹 본체는 교체 시 새 것을
      # 먼저 만들고 기존 것을 지우는데(create_before_destroy), 이름이 같으면 잠깐 공존이
      # 안 돼 409가 난다. 접두사 뒤 고유값으로 이름이 겹치지 않게 하는 게 필수라 명시함.
      use_name_prefix = true

      iam_role_name = "${var.cluster_name}-MainNodeGroup"

      # v21 기본 ami_type=AL2023_x86_64_STANDARD, use_latest_ami_release_version=true
      instance_types = var.instance_types

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      labels = {
        role = "main"
      }
    }
  }
}
