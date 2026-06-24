# 배포될 AWS 리전
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# 생성될 EKS 클러스터의 이름
variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
  default     = "eks-cluster-C"
}

# VPC에서 사용할 CIDR 블록 (네트워크 대역)
variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

# 워커 노드(EC2)에서 사용할 인스턴스 타입 리스트
variable "instance_types" {
  description = "EKS Node Group Instance Types"
  type        = list(string)
  default     = ["t3.medium"]
}

# 노드 그룹의 최소 인스턴스 개수
variable "node_group_min_size" {
  description = "Min size for node group"
  type        = number
  default     = 1
}

# 노드 그룹의 최대 인스턴스 개수
variable "node_group_max_size" {
  description = "Max size for node group"
  type        = number
  default     = 3
}

# 노드 그룹의 유지할 인스턴스 개수
variable "node_group_desired_size" {
  description = "Desired size for node group"
  type        = number
  default     = 2
}

# --- Outputs ---

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

# 클러스터가 생성된 VPC ID
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
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
