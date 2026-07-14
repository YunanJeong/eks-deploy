#======================================================================
# dev 환경 진입점
#   - provider(호출측 책임) + 공유 모듈 호출
#   - 실제 값은 terraform.tfvars 에서 주입
#======================================================================

provider "aws" {
  region = var.aws_region

  # 모든 리소스에 공통 태그 일괄 적용
  default_tags {
    tags = var.tags
  }
}

module "eks" {
  source = "../../modules/eks-cluster"

  aws_region          = var.aws_region
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  authentication_mode = var.authentication_mode

  vpc_id             = var.vpc_id
  private_subnet_ids = var.private_subnet_ids
  public_subnet_ids  = var.public_subnet_ids
  vpc_cidr           = var.vpc_cidr

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  instance_types          = var.instance_types
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_group_desired_size = var.node_group_desired_size

  access_entries = var.access_entries
  tags           = var.tags
}
