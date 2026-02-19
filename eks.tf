# 공식 AWS EKS 모듈 사용
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31" # EKS 클러스터 버전

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # 노드는 프라이빗 서브넷에 배치

  # EKS Managed Node Groups 설정
  eks_managed_node_groups = {
    main = {
      instance_types = var.instance_types

      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      labels = {
        role = "main"
      }
    }
  }

  # 클러스터 생성자에게 관리자 권한 자동 부여 (Access Entry 방식)
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
