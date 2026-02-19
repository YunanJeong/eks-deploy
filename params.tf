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
