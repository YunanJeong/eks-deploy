# =====================================================================
# Pod Identity 용 IAM 역할
#   - 각 앱(Karpenter / VPC CNI / EBS CSI)이 AWS 리소스를 다루기 위한 역할
#   - Trust: EKS Pod Identity (pods.eks.amazonaws.com)
#   - 역할만 미리 생성해 둠. 실제 연결(association)과 앱(Helm) 배포는 이후 단계.
#   - 코드에는 이름/신뢰관계/권한만 들어가며 비밀정보는 포함되지 않음.
# =====================================================================

# #####################################################################
# ⚠️⚠️  하드코딩 주의: 서비스 어카운트(SA) 이름  ⚠️⚠️
#
#   아래 SA 이름은 "나중에 Helm으로 각 앱을 설치할 때 생성되는 SA 이름"과
#   글자 하나까지 정확히 일치해야 Pod Identity가 작동함. (아래 association에서 참조)
#   → Helm 차트에서 serviceAccount.name / nameOverride 를 바꾸면 여기도 반드시 수정할 것.
#   → 값은 각 앱 Helm 차트의 "기본 SA 이름" 기준.
# #####################################################################
locals {
  pod_identity_sa = {
    karpenter = "karpenter"             # Karpenter 차트 기본 SA
    vpc_cni   = "aws-node"              # VPC CNI(aws-node) 기본 SA
    ebs_csi   = "ebs-csi-controller-sa" # EBS CSI 드라이버 기본 SA
  }
  pod_identity_namespace = "kube-system" # 위 3개 모두 kube-system에 배포됨
}

# "이 IAM 역할을 누가 사용할 수 있는가"를 정하는 문서 (= 신뢰 정책 / trust policy).
#   - IAM 역할에는 항상 두 종류의 정책이 붙음:
#       (1) 신뢰 정책  = "누가 이 역할을 맡을(assume) 수 있나"   ← 지금 이 블록
#       (2) 권한 정책  = "역할을 맡은 뒤 무엇을 할 수 있나"       ← 아래 policy_attachment
#   - 여기서는 "EKS Pod Identity(pods.eks.amazonaws.com)"가 맡을 수 있도록 허용함.
#     즉, Pod Identity로 연결된 파드만 이 역할을 쓸 수 있다는 뜻.
#   - 3개 역할(Karpenter/VPC CNI/EBS)이 맡는 주체가 같으므로 이 문서 하나를 공유함.
#   * aws_iam_policy_document 는 AWS를 조회하는 게 아니라, 이 정책 JSON을 만들어주는 도구.
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"] # 역할 맡기(assume)를 허용하는 표준 액션
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"] # 맡을 수 있는 주체 = EKS Pod Identity
    }
  }
}

# ---------------------------------------------------------------------
# 1) Karpenter — 노드 오토스케일링(비용 절감). EC2 인스턴스 생성/종료 권한 필요.
#    (권한 정책은 Karpenter 배포 시점에 맞춰 별도 부여 예정 — 역할 골격만 선생성)
# ---------------------------------------------------------------------
resource "aws_iam_role" "karpenter" {
  name               = "${var.cluster_name}-Karpenter"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "karpenter" }
}

# ---------------------------------------------------------------------
# 2) VPC CNI — 파드 네트워킹(ENI/IP 관리). AWS 관리형 정책 사용.
# ---------------------------------------------------------------------
resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-AmazonEKSPodIdentityAmazonVPCCNIRole"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "vpc-cni" }
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ---------------------------------------------------------------------
# 3) EBS CSI — 영구 볼륨(EBS) 프로비저닝. AWS 관리형 정책 사용.
# ---------------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-AmazonEKSPodIdentityAmazonEBSCSI"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "ebs-csi" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# =====================================================================
# Pod Identity association (SA ↔ IAM Role 매핑)
#   - 순수 AWS(EKS) 리소스. 대상 SA/파드가 없어도 미리 등록 가능.
#   - service_account 는 위 locals.pod_identity_sa 참조 (하드코딩 주의 배너 참고).
#   - 실제 작동 전제: eks.tf의 eks-pod-identity-agent 애드온.
#   - association은 name 속성이 없으므로 tags의 Name으로 식별성 부여.
# =====================================================================

# Karpenter
resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.pod_identity_namespace
  service_account = local.pod_identity_sa.karpenter
  role_arn        = aws_iam_role.karpenter.arn
  tags            = { Name = "${var.cluster_name}-karpenter", PodIdentity = "karpenter" }
}

# VPC CNI
resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.pod_identity_namespace
  service_account = local.pod_identity_sa.vpc_cni
  role_arn        = aws_iam_role.vpc_cni.arn
  tags            = { Name = "${var.cluster_name}-vpc-cni", PodIdentity = "vpc-cni" }
}

# EBS CSI
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.pod_identity_namespace
  service_account = local.pod_identity_sa.ebs_csi
  role_arn        = aws_iam_role.ebs_csi.arn
  tags            = { Name = "${var.cluster_name}-ebs-csi", PodIdentity = "ebs-csi" }
}
