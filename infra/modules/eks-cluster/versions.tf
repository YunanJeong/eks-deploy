#======================================================================
# Terraform / Provider 요구사항
#   - provider "aws" 블록은 이 모듈을 호출하는 envs/<env>/main.tf 에 둠.
#     (모듈은 재사용 대상이라 provider 정의는 호출측 책임)
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
