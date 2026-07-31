#======================================================================
# 출력값 (Outputs)
#======================================================================

# 배포 후 kubectl 설정 등에 필요한 클러스터 API 엔드포인트
output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

# 배포된 클러스터의 이름
output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

# 배포된 클러스터의 Kubernetes 버전
output "cluster_version" {
  description = "EKS Kubernetes version"
  value       = module.eks.cluster_version
}

# 클러스터가 사용하는 VPC ID (기존 지정 또는 신규 생성)
output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = local.vpc_id
}

# 클러스터 통신에 필요한 CA 데이터 (base64 인코딩됨)
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# 클러스터가 배포된 AWS 리전
output "aws_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}

# 워커 노드 인스턴스 타입
output "node_instance_types" {
  description = "EKS node group instance types"
  value       = var.instance_types
}

# 노드 그룹 오토스케일링 설정 (min/desired/max)
output "node_group_scaling" {
  description = "EKS node group scaling configuration (min/desired/max)"
  value = {
    min     = var.node_group_min_size
    desired = var.node_group_desired_size
    max     = var.node_group_max_size
  }
}

# --- IAM 역할 목록 (plan/apply 하단에서 확인용) ---

# [1] EKS 모듈이 기본 생성하는 역할 (클러스터/노드 동작 필수)
output "iam_roles_base" {
  description = "Base IAM roles auto-created by the EKS module (name => purpose)"
  value = {
    "${module.eks.cluster_iam_role_name}"                                  = "[기본 필수] 클러스터(컨트롤플레인) 역할"
    "${try(module.eks.eks_managed_node_groups["main"].iam_role_name, "")}" = "[기본 필수] 노드그룹(main) 역할"
  }
}

# [2] 각 앱을 위해 생성한 Pod Identity 역할 (용도 표기)
output "iam_roles_app" {
  description = "Application Pod Identity roles created by this project (name => purpose)"
  value = {
    "${module.karpenter.iam_role_name}"      = "Karpenter 컨트롤러 - 노드 오토스케일링(EC2 생성/종료)"
    "${module.karpenter.node_iam_role_name}" = "Karpenter 노드 - Karpenter가 띄운 EC2용 역할"
    "${aws_iam_role.vpc_cni.name}"           = "VPC CNI - 파드 네트워킹(ENI/IP 관리)"
    "${aws_iam_role.ebs_csi.name}"           = "EBS CSI - 영구 볼륨(EBS) 프로비저닝"
    "${aws_iam_role.lb_controller.name}"     = "LB Controller - ALB/NLB 프로비저닝"
  }
}

# Karpenter Helm 설치 시 필요한 값 (컨트롤러 역할·SQS 큐·노드 역할)
output "karpenter" {
  description = "Karpenter 설치용 값 (Helm/EC2NodeClass에서 사용)"
  value = {
    iam_role_arn    = module.karpenter.iam_role_arn       # 컨트롤러 역할
    node_iam_role   = module.karpenter.node_iam_role_name # EC2NodeClass의 role
    queue_name      = module.karpenter.queue_name         # Helm settings.interruptionQueue
    service_account = module.karpenter.service_account
    namespace       = module.karpenter.namespace
  }
}
