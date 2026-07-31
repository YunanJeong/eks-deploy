#======================================================================
# 입력 변수 (envs -> 모듈로 전달)
#   - 모듈(../../modules/eks-stack/variables.tf)과 동일한 선언.
#   - 값은 terraform.tfvars 에서 주입.
#======================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "cluster_name" {
  description = "EKS Cluster Name (required, no default)"
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.36"
}

variable "authentication_mode" {
  description = "EKS cluster authentication mode (API, API_AND_CONFIG_MAP, CONFIG_MAP)"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "vpc_id" {
  description = "Existing VPC ID to deploy into. Leave empty to create a new VPC."
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs (required when vpc_id is set)"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs (used when vpc_id is set)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR for the new VPC (used only when creating a new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_types" {
  description = "EKS Node Group Instance Types"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Min size for node group"
  type        = number
  default     = 1
}

variable "node_group_max_size" {
  description = "Max size for node group"
  type        = number
  default     = 3
}

variable "node_group_desired_size" {
  description = "Desired size for node group"
  type        = number
  default     = 2
}

variable "node_ami_release_version" {
  description = "Pin node group AMI release version. Empty means always use the latest."
  type        = string
  default     = ""
}

variable "access_entries" {
  description = "Additional IAM principals granted cluster access"
  type = map(object({
    principal_arn = string
    policy_arn    = string
    namespaces    = optional(list(string), [])
  }))
  default = {}
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Cluster   = "default"
    Terraform = "true"
  }
}
