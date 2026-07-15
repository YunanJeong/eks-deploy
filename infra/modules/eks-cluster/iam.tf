#======================================================================
# Pod Identity - 앱(Karpenter / VPC CNI / EBS CSI)용 IAM 역할 및 연결
#   - IAM 역할 정의는 전부 이 파일에 모음.
#   - SA<->역할 "연결(association)" 위치는 소유 주체에 따라 갈림 (아래 ASSOCIATION 섹션 참고).
#   - 코드에는 이름/신뢰관계/권한만 들어가며 비밀정보는 포함되지 않음.
#======================================================================

# ⚠️ 하드코딩 주의: SA 이름은 실제 파드의 SA와 정확히 일치해야 Pod Identity가 작동함.
#   vpc_cni / ebs_csi = 애드온 고정 SA (eks.tf 애드온 association에서 참조)
#   lb_controller     = Helm 설치 시 생성 SA (Helm 차트에서 이름 바꾸면 여기도 수정)
#   * Karpenter는 전용 서브모듈(karpenter.tf)이 역할·정책·SQS·association까지 관리함.
locals {
  pod_identity_sa = {
    vpc_cni       = "aws-node"
    ebs_csi       = "ebs-csi-controller-sa"
    lb_controller = "aws-load-balancer-controller"
  }
  pod_identity_namespace = "kube-system"
}

# --- IAM 역할 (Roles) -------------------------------------------------

# 공통 신뢰 정책 = "누가 이 역할을 맡을 수 있나" -> EKS Pod Identity만 허용.
#   (역할엔 신뢰 정책 + 권한 정책이 붙음. 아래 역할들이 신뢰 주체가 같아 하나를 공유.)
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# VPC CNI - 파드 네트워킹(ENI/IP). AWS 관리형 정책.
resource "aws_iam_role" "vpc_cni" {
  name               = "${var.cluster_name}-AmazonEKSPodIdentityAmazonVPCCNIRole"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "vpc-cni" }
}
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# EBS CSI - 영구 볼륨(EBS) 프로비저닝. AWS 관리형 정책.
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-AmazonEKSPodIdentityAmazonEBSCSI"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "ebs-csi" }
}
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# LB Controller - ALB/NLB 프로비저닝. AWS 관리형 정책이 없어 공식 정책(JSON)을 부착.
#   파일명(official-iam-policy-for-lb-controller-v2.14.1.json)에 공식 여부·버전 표기.
#   아래 공식 iam_policy.json을 그대로 받은 것(내용 수정 X):
#   https://github.com/kubernetes-sigs/aws-load-balancer-controller/raw/v2.14.1/docs/install/iam_policy.json
#   ⚠️ LB Controller 버전 업 시 새 버전 파일로 교체(파일명 버전도 함께 변경) 후 아래 경로 수정.
resource "aws_iam_role" "lb_controller" {
  name               = "${var.cluster_name}-AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = { PodIdentity = "lb-controller" }
}
resource "aws_iam_policy" "lb_controller" {
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/official-iam-policy-for-lb-controller-v2.14.1.json")
}
resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# --- SA <-> 역할 연결 (Pod Identity Association) ----------------------
# 연결 위치가 갈리는 기준 (AWS 권장):
#   - 애드온인 것(VPC CNI, EBS CSI) -> eks.tf 애드온이 소유 (삭제 시 연결도 함께 정리)
#   - LB Controller(Helm 배포) -> 묶을 애드온이 없어 여기 standalone
#   - Karpenter -> 전용 서브모듈(karpenter.tf)이 association까지 자체 생성
# 작동 전제: eks.tf의 eks-pod-identity-agent 애드온.

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.pod_identity_namespace
  service_account = local.pod_identity_sa.lb_controller # "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lb_controller.arn
  tags            = { Name = "${var.cluster_name}-lb-controller", PodIdentity = "lb-controller" }
}
