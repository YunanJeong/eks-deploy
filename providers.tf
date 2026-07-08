#======================================================================
# Terraform / Provider 설정
#   - required_version, required_providers, AWS provider(공통 태그 포함)
#======================================================================

terraform {
  required_version = ">= 1.5.0" # Terraform 최소 버전 요구사항

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS Provider 버전 고정
    }
  }
}

# AWS Provider 설정
# - region: params.tf의 var.aws_region 사용
# - default_tags: 모든 리소스에 공통 태그를 일괄 적용하여 태그 관리를 일원화함
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}
