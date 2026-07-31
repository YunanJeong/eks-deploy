#======================================================================
# 출력값 (모듈 output 재노출 -> plan/apply 하단 표시)
#======================================================================

output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.this.cluster_endpoint
}

output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.this.cluster_name
}

output "cluster_version" {
  description = "EKS Kubernetes version"
  value       = module.this.cluster_version
}

output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = module.this.vpc_id
}

output "aws_region" {
  description = "AWS region where the cluster is deployed"
  value       = module.this.aws_region
}

output "node_instance_types" {
  description = "EKS node group instance types"
  value       = module.this.node_instance_types
}

output "node_group_scaling" {
  description = "EKS node group scaling configuration (min/desired/max)"
  value       = module.this.node_group_scaling
}

output "iam_roles_base" {
  description = "Base IAM roles auto-created by the EKS module"
  value       = module.this.iam_roles_base
}

output "iam_roles_app" {
  description = "Application Pod Identity roles created by this project"
  value       = module.this.iam_roles_app
}

output "karpenter" {
  description = "Karpenter 설치용 값 (Helm/EC2NodeClass에서 사용)"
  value       = module.this.karpenter
}
