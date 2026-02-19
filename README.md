# AWS EKS Deployment with Terraform

이 프로젝트는 Terraform을 사용하여 AWS 환경에 Amazon EKS 클러스터와 필요한 네트워크 인프라(VPC)를 자동으로 구축하는 모듈입니다.

## 📂 프로젝트 구조

- `providers.tf`: AWS 및 Kubernetes 프로바이더 설정
- `params.tf`: 자주 수정되는 변수들 (리전, 클러스터명, 노드 사양 등) 모음
- `vpc.tf`: EKS용 네트워크(VPC, Subnet, NAT Gateway) 정의
- `eks.tf`: EKS 클러스터 및 Managed Node Group 정의
- `outputs.tf`: 생성된 리소스의 주요 정보 출력

## 🚀 사용 방법

### 1. 사전 요구사항
- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) 설치
- [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 및 자격 증명(Access Key/Secret Key) 설정 완료 (`aws configure`)

### 2. 초기화 (Initialization)
모듈과 플러그인을 설치합니다.
```bash
terraform init
```

### 3. 변경 사항 확인 (Planning)
실제로 배포하기 전에 생성될 리소스를 미리 확인합니다.
```bash
terraform plan
```

### 4. 배포 (Apply)
인프라를 AWS에 배포합니다.
```bash
terraform apply
```

### 5. 클러스터 접속 설정 (Kubeconfig 업데이트)
배포 완료 후, `kubectl` 명령어를 사용할 수 있도록 로컬 설정을 업데이트합니다.
```bash
aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>
```

## ⚠️ 주의 사항

1. **비용 발생**: EKS 클러스터 유지 비용(시간당 약 $0.10)과 NAT Gateway, EC2 인스턴스 사용량에 따른 비용이 AWS 계정에 청구됩니다. 테스트 후에는 반드시 삭제(`terraform destroy`)하세요.
2. **NAT Gateway**: 프라이빗 서브넷의 노드들이 외부와 통신하기 위해 필수적입니다. 비용 절감을 위해 `vpc.tf`에서 `single_nat_gateway = true`로 설정되어 있습니다. 운영 환경에서는 가용성을 위해 이를 `false`로 변경하는 것을 권장합니다.
3. **IAM 권한**: `terraform apply`를 실행하는 IAM 사용자는 VPC 및 EKS 관련 리소스를 생성할 수 있는 충분한 권한(최소 `AdministratorAccess` 또는 관련 세부 권한)이 있어야 합니다.
4. **상태 관리**: 기본적으로 `terraform.tfstate` 파일이 로컬에 생성됩니다. 협업 시에는 S3와 DynamoDB를 사용하여 원격 백엔드(Remote Backend)를 설정하는 것이 좋습니다.
5. **민감 정보**: `params.tf`에 민감한 정보가 포함되지 않도록 주의하고, 필요한 경우 환경 변수(`TF_VAR_xxx`)나 `terraform.tfvars` 파일을 활용하세요.

## 🧹 리소스 삭제
더 이상 인프라가 필요하지 않을 때 아래 명령어로 모든 리소스를 제거합니다.
```bash
terraform destroy
```
