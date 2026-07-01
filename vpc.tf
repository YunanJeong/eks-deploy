# =====================================================================
# 네트워크
#   - var.vpc_id 를 비우면: 신규 VPC/서브넷/NAT 를 생성함
#   - var.vpc_id 를 지정하면: 기존 VPC/서브넷을 그대로 사용함
# =====================================================================

# 신규 VPC를 생성하는지 여부
locals {
  create_vpc = var.vpc_id == ""
}

# 가용 영역(AZ) 정보를 동적으로 가져옴 (신규 생성 시 사용)
data "aws_availability_zones" "available" {}

# 공식 AWS VPC 모듈 — var.vpc_id 가 비어 있을 때만 생성
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  count = local.create_vpc ? 1 : 0

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # 선택한 리전의 첫 3개 가용 영역에 서브넷 생성
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  # NAT 게이트웨이 활성화 (프라이빗 서브넷 인터넷 연결용)
  enable_nat_gateway = true
  single_nat_gateway = true # 비용 절감을 위해 단일 NAT 게이트웨이 설정

  # EKS 및 로드 밸런서 동작을 위한 필수 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1 # Public ELB 생성용
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1 # Internal ELB 생성용
  }
}

# 신규/기존 여부와 무관하게 EKS가 참조할 최종 네트워크 값
locals {
  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnets : var.private_subnet_ids
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnets : var.public_subnet_ids
}
