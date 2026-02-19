# Terraform 및 Required Providers 설정
terraform {
  required_version = ">= 1.5.0" # Terraform 최소 버전 요구사항

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS Provider 버전 고정
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0" # Kubernetes 리소스 관리를 위한 Provider
    }
  }
}

# AWS Provider 설정: params.tf에 정의된 리전을 사용함
provider "aws" {
  region = var.aws_region
}
