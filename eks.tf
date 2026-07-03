# 공식 AWS EKS 모듈 사용
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids # 노드는 프라이빗 서브넷에 배치

  # --- 접근 제어 ---
  # 인증 모드: 기본 API_AND_CONFIG_MAP (Access Entry + 레거시 ConfigMap 병행)
  authentication_mode = var.authentication_mode

  # 클러스터 생성자에게 관리자 권한 자동 부여 (Access Entry 방식)
  enable_cluster_creator_admin_permissions = true

  # --- 엔드포인트 접근 ---
  # 원격에서 kubectl 접근이 가능하도록 퍼블릭 엔드포인트 활성화
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  cluster_endpoint_private_access      = true

  # --- KMS / 로그 비활성화 (컴플라이언스 준수 or 감사 필요시 활성화. kms:*, logs:* 권한 필요) ---
  # KMS off → Secret은 AWS 기본 암호화로 저장됨(평문 아님). CMK/envelope 암호화를
  create_kms_key            = false
  cluster_encryption_config = {}

  # 로그 off → 컨트롤플레인 감사로그 미수집. 규제상 감사 추적 필요하면 log_types 채울 것.
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  # --- 관리형 애드온 ---
  # Pod Identity 에이전트: association이 실제 작동하려면 이 애드온이 필수 전제.
  cluster_addons = {
    eks-pod-identity-agent = {}
  }

  # EKS Managed Node Groups 설정
  eks_managed_node_groups = {
    main = {
      # 노드그룹 이름과 IAM 역할을 클러스터명 기반으로 고정.
      # (기본 name_prefix 모드는 랜덤 접미사가 붙어 cluster_name으로 구분되지 않음)
      # state를 버리고 새 cluster_name으로 재배포해도 이름이 겹치지 않도록 함.
      name                     = "${var.cluster_name}-main"
      use_name_prefix          = false
      iam_role_name            = "${var.cluster_name}-main-node"
      iam_role_use_name_prefix = false

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
