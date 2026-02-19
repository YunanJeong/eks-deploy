# 가용 영역(AZ) 정보를 동적으로 가져옴
data "aws_availability_zones" "available" {}

# 공식 AWS VPC 모듈 사용
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # 선택한 리전의 첫 3개 가용 영역에 서브넷 생성
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  # NAT 게이트웨이 활성화 (프라이빗 서브넷 인터넷 연결용)
  enable_nat_gateway = true
  single_nat_gateway = true # 비용 절감을 위해 단일 NAT 게이트웨이 설정

  # EKS 및 로드 밸런서 동작을 위한 필수 태그 설정
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1 # Public ELB 생성용
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1 # Internal ELB 생성용
  }
}
