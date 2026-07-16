#======================================================================
# 입력 변수 (Variables)
#======================================================================

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
  default     = "1.36"
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

# --- 네트워크: 값을 지정하면 기존 VPC/서브넷에 붙고, 비우면 신규 생성 ---

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

# --- 엔드포인트 접근 ---

# kubectl이 붙는 컨트롤플레인(API 서버) 엔드포인트의 접근 허용 IP. (노드 접근과 무관)
# 0.0.0.0/0이어도 접근엔 AWS 자격증명(액세스 키)+access entry 권한이 필요하므로 즉시 뚫리진 않음.
# ⚠️ 외부 공유 주의: 사무실/VPN 실제 IP가 드러남. 기본 전체 허용이라 운영은 좁힐 것.
variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# --- 노드 그룹 ---

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

# --- 액세스 (클러스터 생성자 외 추가 멤버) ---
# 클러스터에 kubectl 접근을 허용할 IAM 유저/역할 목록.
#   key           : 임의 식별자 (예: "devops-lead")
#   principal_arn : 대상 IAM 유저/역할 ARN
#   policy_arn    : 부여할 EKS access policy ARN
#     - .../AmazonEKSClusterAdminPolicy : 클러스터 전체 관리자
#     - .../AmazonEKSAdminPolicy        : 관리자(일부 제한)
#     - .../AmazonEKSEditPolicy         : 리소스 편집
#     - .../AmazonEKSViewPolicy         : 읽기 전용
#   namespaces    : 비우면([]) 클러스터 전체, 채우면 해당 네임스페이스로 범위 제한
# 생성자(Terraform 실행 IAM)는 enable_cluster_creator_admin_permissions로 자동 관리자.
variable "access_entries" {
  description = "Additional IAM principals granted cluster access"
  type = map(object({
    principal_arn = string
    policy_arn    = string
    namespaces    = optional(list(string), [])
  }))
  default = {}
}

# --- 태그 (provider default_tags로 모든 리소스에 일괄 적용됨) ---
variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Terraform   = "true"
    Project     = "eks-deploy"
  }
}
