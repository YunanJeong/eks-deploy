# AWS EKS Deployment with Terraform

Terraform으로 AWS에 EKS 클러스터 + 전용 VPC를 한 번에 구축하는 IaC 프로젝트.
AWS 공식 모듈(VPC, EKS) 기반으로 격리된 독립 환경을 새로 생성함.

## 📂 프로젝트 구조

| 파일 | 역할 |
|------|------|
| `providers.tf` | Terraform 버전 요구사항, AWS 프로바이더 및 공통 태그(`default_tags`) 설정 |
| `params.tf` | 입력 변수(`variable`) 선언 + 출력값(`output`) 정의 |
| `vpc.tf` | 네트워크 — VPC, 퍼블릭/프라이빗 서브넷, NAT/인터넷 게이트웨이 |
| `eks.tf` | EKS 클러스터, Managed Node Group |
| `terraform.tfvars.example` | 변수값 샘플 템플릿 (**git 포함**) |
| `terraform.tfvars` | 실제 배포용 변수값 (**git 제외**) |

> `.tf` 파일은 파일명과 무관하게 디렉터리 전체가 합쳐져 해석됨. 위 분리는 가독성용 관례.

## 🏗️ 인프라 특징

- **유연한 네트워크** — `vpc_id` 미지정 시 EKS 전용 VPC·서브넷·게이트웨이를 신규 생성, 지정 시 기존 네트워크에 붙음.
- **네트워크 격리** — 워커 노드는 프라이빗 서브넷 배치, 외부 통신은 NAT 경유. ALB/NLB용 퍼블릭 서브넷은 별도. 첫 3개 AZ에 분산.
- **표준 구성** — 보안 그룹, IAM 역할, Secret 암호화용 KMS 키를 모범 사례대로 자동 구성. 클러스터 생성자에겐 Access Entry로 관리자 권한 자동 부여.
- **일괄 태깅** — `default_tags`로 모든 리소스에 공통 태그 적용.
- **블루/그린 업그레이드** — `cluster_name`·`cluster_version`을 바꿔 신규 클러스터를 나란히 세우는 방식 지원.

## ⚙️ 주요 변수

`params.tf`에 선언됨. `cluster_name`만 필수, 나머지는 기본값 있어 생략 가능.

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `cluster_name` | EKS 클러스터 이름 | **없음 (필수)** |
| `cluster_version` | Kubernetes 버전 (블루/그린 시 상향) | `1.33` |
| `authentication_mode` | 인증 모드 (`API` / `API_AND_CONFIG_MAP` / `CONFIG_MAP`) | `API_AND_CONFIG_MAP` |
| `aws_region` | 배포 리전 | `ap-northeast-2` |
| `vpc_id` | 기존 VPC ID (비우면 신규 생성) | `""` |
| `private_subnet_ids` | 기존 프라이빗 서브넷 (기존 VPC 사용 시 필수) | `[]` |
| `public_subnet_ids` | 기존 퍼블릭 서브넷 | `[]` |
| `vpc_cidr` | 신규 VPC CIDR (신규 생성 시만) | `10.0.0.0/16` |
| `cluster_endpoint_public_access_cidrs` | 퍼블릭 API 접근 허용 CIDR | `["0.0.0.0/0"]` |
| `instance_types` | 노드 인스턴스 타입 | `["t3.medium"]` |
| `node_group_min_size` | 노드 최소 개수 | `1` |
| `node_group_desired_size` | 노드 희망 개수 | `2` |
| `node_group_max_size` | 노드 최대 개수 | `3` |
| `tags` | 전 리소스 공통 태그 (`default_tags`) | Environment/Terraform/Project |

> `cluster_name`은 오배포 방지를 위해 기본값 없음. 값을 안 주면 실행 시 입력을 요구함.

**네트워크** — `vpc_id`를 비우면 전용 VPC를 신규 생성하고, 지정하면 기존 VPC·서브넷에 클러스터를 붙임.

**인증 모드** — 레거시 앱 호환을 위해 기본은 Access Entry + `aws-auth` ConfigMap 병행(`API_AND_CONFIG_MAP`). 레거시가 없으면 `API`(Access Entry 전용)로 좁힐 수 있음.

**엔드포인트** — 원격 `kubectl` 접근을 위해 퍼블릭 엔드포인트가 활성화됨. 운영에선 `cluster_endpoint_public_access_cidrs`로 접근 IP를 좁히는 것을 권장함.

## 🚀 사용 방법

**사전 요구사항**
- [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) 설치
- [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 + 자격 증명 설정 (`aws configure`)

**1. 초기화** — 모듈·프로바이더 설치
```bash
terraform init
```

**2. 변수 설정** — 샘플 복사 후 값 수정 (최소 `cluster_name`)
```bash
cp terraform.tfvars.example terraform.tfvars
```
- `terraform.tfvars`(및 `*.auto.tfvars`)는 예약된 파일명이라 자동 로드됨.
- `.gitignore` 제외 대상이라 환경별 설정·민감값 넣기 안전함.
- 다른 파일명은 `-var-file`로, 특정 값만 덮어쓸 땐 `-var`로 지정.
  ```bash
  terraform apply -var-file="prod.tfvars"
  terraform apply -var="cluster_name=my-cluster"
  ```

**3. 변경 확인** — 생성될 리소스 미리보기
```bash
terraform plan
```

**4. 배포**
```bash
terraform apply
```

**5. 접속 설정** — 로컬 kubeconfig 갱신
```bash
aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>
```

## ⚠️ 주의 사항

- **비용** — EKS(시간당 ~$0.10), NAT Gateway, EC2, KMS 키에 과금됨. 테스트 후 `terraform destroy` 필수.
- **NAT Gateway** — 비용 절감용 `single_nat_gateway = true` 설정. 운영에선 가용성 위해 `false`(AZ별 NAT) 권장.
- **IAM 권한** — 실행 주체는 VPC·EKS 생성 권한 필요 (최소 `AdministratorAccess` 또는 상응 권한).
- **상태 관리** — `terraform.tfstate`가 로컬 생성됨. 협업 시 S3 + DynamoDB 원격 백엔드 권장.
- **민감 정보** — `terraform.tfvars`, `*.tfstate`는 git 제외됨. 민감값은 이 파일들 또는 `TF_VAR_xxx` 환경 변수로만 다룰 것.
- **콘솔 관리 시 drift** — 배포 후 웹 콘솔에서 노드 수·설정을 바꾸면 Terraform state와 어긋남. 이후 `terraform apply`는 코드 기준으로 되돌리려 하므로, 콘솔 변경 후에는 apply를 피하거나 코드에 반영할 것.

## 🧹 리소스 삭제

state가 남아 있으면 아래 한 줄로 전부 제거됨.
```bash
terraform destroy
```

### state를 버린 경우 (수동 삭제 참고용)

state를 지웠다면 `destroy`가 안 되므로 콘솔/CLI로 직접 삭제해야 함. 모든 이름은 `cluster_name` 기반. **아래 순서(의존성)대로** 지울 것.

1. **노드** — Managed Node Group(`<name>-main`) → 노드 IAM 역할(`<name>-main-node`)·정책 → Launch Template
2. **애드온** — CoreDNS, kube-proxy, VPC CNI (노드그룹과 함께 정리됨)
3. **컨트롤 플레인** — EKS 클러스터 → 클러스터 IAM 역할 → 클러스터 보안 그룹
4. **인증/권한** — OIDC 프로바이더(IRSA), Access Entry·정책 연결
5. **로그/암호화** — CloudWatch 로그 그룹(`/aws/eks/<name>/cluster`), KMS 키·별칭
6. **네트워크** (신규 생성한 경우) — NAT 게이트웨이 → 서브넷 → 인터넷 게이트웨이 → 라우팅 테이블 → VPC

**⚠️ 목록에 안 잡히는 숨은 리소스 (남으면 과금·삭제 차단됨)**
- **EIP** — NAT 게이트웨이를 지워도 탄력적 IP는 남아 과금됨. 별도 해제.
- **로드밸런서·ENI** — 앱에서 `Service type=LoadBalancer`를 썼다면 AWS가 만든 ELB·보안그룹이 남아 VPC 삭제를 막음.
- **KMS 키** — 즉시 삭제 안 되고 7~30일 삭제 대기 상태로 전환됨.
