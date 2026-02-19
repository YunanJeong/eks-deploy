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
