#======================================================================
# dev 환경 진입점
#   - provider(호출측 책임) + 공유 모듈 호출
#   - 실제 값은 terraform.tfvars 에서 주입
#======================================================================

# Terraform·Cluster는 여기서 자동 부여하며, merge 뒤 인자로 둬 tfvars가 못 덮음(오버라이드 불가).
locals {
  common_tags = merge(var.tags, {
    Terraform = "true"
    Cluster   = var.cluster_name
  })
}

provider "aws" {
  region = var.aws_region

  # 프로바이더가 모든 리소스에 공통 태그 일괄 적용.
  default_tags {
    tags = local.common_tags
  }
}

module "this" {
  source = "../../modules/eks-stack"

  aws_region          = var.aws_region
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  authentication_mode = var.authentication_mode

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
  vpc_cidr           = var.vpc_cidr

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  instance_types           = var.instance_types
  node_group_min_size      = var.node_group_min_size
  node_group_max_size      = var.node_group_max_size
  node_group_desired_size  = var.node_group_desired_size
  node_ami_release_version = var.node_ami_release_version

  access_entries = var.access_entries

  # 대부분은 위 default_tags가 처리하나, 노드 launch template은 닿지 않아 따로 넘긴다.
  tags = local.common_tags
}
