#======================================================================
# Karpenter - 전용 서브모듈로 IAM/SQS/association 일괄 관리
#   - 컨트롤러 IAM 역할 + 권한 정책(v1) + SQS 인터럽션 큐
#     + 노드 IAM 역할 + Pod Identity association 을 모두 생성.
#   - Karpenter 컨트롤러(파드) 자체는 Helm으로 설치 (apps/karpenter, 범위 밖).
#   - LB Controller처럼 정책을 수동으로 안 박는 이유: Karpenter 정책은 SQS 큐·
#     노드역할 ARN 등 리소스에 종속돼 있어 서브모듈이 참조해 생성하는 게 정석.
#======================================================================

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.0"

  cluster_name = module.eks.cluster_name
  region       = var.aws_region # v21 신규

  # 인증: Pod Identity 방식 + association 자동 생성 (SA: karpenter / kube-system)
  # v21은 Pod Identity가 기본이라 enable_pod_identity 인자 없음.
  create_pod_identity_association = true
  namespace                       = "kube-system"
  service_account                 = "karpenter"

  # 컨트롤러 IAM 역할 (이름은 접두사로, 뒤에 고유값 자동 부착 - default)
  # v21은 v1 권한 정책이 기본이라 enable_v1_permissions 인자 없음.
  iam_role_name = "${var.cluster_name}-KarpenterController"

  # 컨트롤러 권한을 인라인 정책으로 생성(한도 10,240자). 관리형 정책은 6,144자
  # 한도라 v21 정책이 이를 초과해 LimitExceeded(PolicySize 6144)가 남.
  enable_inline_policy = true

  # SQS 인터럽션 큐 생성 (Spot 중단·EC2 이벤트 처리)
  enable_spot_termination = true

  # 노드 IAM 역할: Karpenter가 띄우는 노드가 쓸 역할. CNI 정책 등 부착.
  create_node_iam_role = true
  node_iam_role_name   = "${var.cluster_name}-KarpenterNode"

  tags = var.tags
}
