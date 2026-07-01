# =====================================================================
# 입력 변수 (Variables)
# =====================================================================

# 배포될 AWS 리전
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

# 생성될 EKS 클러스터의 이름 (필수: 환경마다 반드시 지정해야 함)
# 블루/그린 업그레이드 시 신규 클러스터 이름을 명시적으로 지정하도록 default 없음.
variable "cluster_name" {
  description = "EKS Cluster Name (required, no default)"
  type        = string
}

# EKS 클러스터 Kubernetes 버전
# 블루/그린 업그레이드 시 이 값만 올려 신규 클러스터를 생성함.
variable "cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.33"
}

# 클러스터 인증 모드
#   API_AND_CONFIG_MAP : Access Entry + 레거시 aws-auth ConfigMap 병행 (기본, 레거시 앱 호환)
#   API                : Access Entry 전용 (ConfigMap 비활성화)
#   CONFIG_MAP         : 레거시 전용 (권장하지 않음)
variable "authentication_mode" {
  description = "EKS cluster authentication mode (API, API_AND_CONFIG_MAP, CONFIG_MAP)"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

# ---------------------------------------------------------------------
# 네트워크: 값을 지정하면 기존 VPC/서브넷에 붙고, 비우면 신규 생성함.
# ---------------------------------------------------------------------

# 기존 VPC ID. 비워두면("") 신규 VPC를 생성함.
variable "vpc_id" {
  description = "Existing VPC ID to deploy into. Leave empty to create a new VPC."
  type        = string
  default     = ""
}

# 기존 프라이빗 서브넷 ID 목록 (vpc_id 지정 시 필수). 노드가 배치됨.
variable "private_subnet_ids" {
  description = "Existing private subnet IDs (required when vpc_id is set)"
  type        = list(string)
  default     = []
}

# 기존 퍼블릭 서브넷 ID 목록 (vpc_id 지정 시, 퍼블릭 LB용).
variable "public_subnet_ids" {
  description = "Existing public subnet IDs (used when vpc_id is set)"
  type        = list(string)
  default     = []
}

# 신규 VPC를 생성할 때 사용할 CIDR 블록 (vpc_id를 비웠을 때만 적용).
variable "vpc_cidr" {
  description = "CIDR for the new VPC (used only when creating a new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

# ---------------------------------------------------------------------
# 엔드포인트 접근
# ---------------------------------------------------------------------

# 퍼블릭 API 엔드포인트 접근을 허용할 CIDR 목록.
# 기본 0.0.0.0/0(전체 허용)이지만, 운영에서는 사무실/VPN IP로 좁히는 것을 권장함.
# ⚠️ 보안 유의: 실제 사무실/VPN IP 대역이 노출되므로 값을 외부에 공유하지 말 것.
variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------
# 노드 그룹
# ---------------------------------------------------------------------

# 워커 노드(EC2)에서 사용할 인스턴스 타입 리스트
variable "instance_types" {
  description = "EKS Node Group Instance Types"
  type        = list(string)
  default     = ["t3.medium"]
}

# 노드 그룹의 최소 인스턴스 개수
variable "node_group_min_size" {
  description = "Min size for node group"
  type        = number
  default     = 1
}

# 노드 그룹의 최대 인스턴스 개수
variable "node_group_max_size" {
  description = "Max size for node group"
  type        = number
  default     = 3
}

# 노드 그룹의 유지할 인스턴스 개수
variable "node_group_desired_size" {
  description = "Desired size for node group"
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------
# 태그 (provider default_tags로 모든 리소스에 일괄 적용됨)
# ---------------------------------------------------------------------
variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "eks-deploy"
  }
}

# =====================================================================
# 출력값 (Outputs)
# =====================================================================

# 배포 후 kubectl 설정 등에 필요한 클러스터 API 엔드포인트
output "cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

# 배포된 클러스터의 이름
output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

# 배포된 클러스터의 Kubernetes 버전
output "cluster_version" {
  description = "EKS Kubernetes version"
  value       = module.eks.cluster_version
}

# 클러스터가 사용하는 VPC ID (기존 지정 또는 신규 생성)
output "vpc_id" {
  description = "VPC ID used by the cluster"
  value       = local.vpc_id
}

# 클러스터 통신에 필요한 CA 데이터 (base64 인코딩됨)
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# 클러스터가 배포된 AWS 리전
output "aws_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}

# 워커 노드 인스턴스 타입
output "node_instance_types" {
  description = "EKS node group instance types"
  value       = var.instance_types
}

# 노드 그룹 오토스케일링 설정 (min/desired/max)
output "node_group_scaling" {
  description = "EKS node group scaling configuration (min/desired/max)"
  value = {
    min     = var.node_group_min_size
    desired = var.node_group_desired_size
    max     = var.node_group_max_size
  }
}
