# AWS EKS Deployment with Terraform

Terraform으로 AWS에 EKS 클러스터 + VPC를 구축하는 IaC 프로젝트.
AWS 공식 모듈(VPC, EKS) 기반이며, `vpc_id` 지정 시 **기존 네트워크에 붙고** 비우면 **전용 VPC를 신규 생성**함.

```bash
terraform init
cp terraform.tfvars.example terraform.tfvars   # 값 수정 (최소 cluster_name)
terraform plan                                 # ⚠️ '0 to destroy' 확인
terraform apply
```

> ⚠️ **기존 클러스터와 네트워크를 공유해 배포한다면** apply 전에 반드시 `terraform plan`에서 **`0 to destroy` / replace 없음**을 확인할 것. → [기존 시스템 영향도](#️-기존-시스템-영향도)

---

## 📂 프로젝트 구조

| 파일 | 역할 |
|------|------|
| `providers.tf` | Terraform 버전 요구사항, AWS 프로바이더 및 공통 태그(`default_tags`) |
| `params.tf` | 입력 변수(`variable`) 선언 + 출력값(`output`) |
| `vpc.tf` | 네트워크 — VPC, 서브넷, NAT/인터넷 게이트웨이 |
| `eks.tf` | EKS 클러스터, Managed Node Group |
| `terraform.tfvars.example` | 변수값 샘플 템플릿 (**git 포함**) |
| `terraform.tfvars` | 실제 배포용 변수값 (**git 제외**) |

> `.tf`는 파일명과 무관하게 디렉터리 전체가 합쳐져 해석됨. 위 분리는 가독성용 관례.

## 🏗️ 인프라 특징

| | |
|------|------|
| **유연한 네트워크** | `vpc_id` 미지정 시 전용 VPC 신규 생성, 지정 시 기존 네트워크에 붙음 |
| **네트워크 격리** | 노드는 프라이빗 서브넷, 외부 통신은 NAT 경유. LB용 퍼블릭 서브넷 별도. 3 AZ 분산 |
| **표준 구성** | 보안 그룹·IAM·KMS(Secret 암호화) 자동 구성. 생성자에 Access Entry 관리자 권한 |
| **일괄 태깅** | `default_tags`로 모든 리소스에 공통 태그 |
| **블루/그린** | `cluster_name`·`cluster_version`을 바꿔 신규 클러스터를 나란히 세움 |

## ⚙️ 설정 참고

전체 변수와 기본값은 **`terraform.tfvars.example`** 에 주석과 함께 정리돼 있음. 아래는 알아둘 핵심만.

- **`cluster_name`만 필수** — 나머지는 `params.tf` 기본값 사용 (생략 가능).
- **노드 방식** — EKS Managed Node Group으로 기본 노드를 구성. **EKS Auto Mode는 추가 비용이 발생하므로 사용하지 않고**, 비용 절감을 위해 **Karpenter를 Helm 차트로 직접 설치·관리**함 (이 Terraform 범위 밖).
- **인증 모드** — 기본 `API_AND_CONFIG_MAP` (Access Entry + 레거시 `aws-auth` ConfigMap 병행). 레거시 앱 없으면 `API`로 좁힐 수 있음.
- **엔드포인트** — 원격 `kubectl`용 퍼블릭 활성화. 운영에선 `cluster_endpoint_public_access_cidrs`로 접근 IP를 좁힐 것.

## 🚀 사용 방법

**사전 요구사항** — [Terraform CLI](https://developer.hashicorp.com/terraform/downloads), [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 + `aws configure`

```bash
# 1. 초기화 (모듈·프로바이더 설치)
terraform init

# 2. 변수 설정 (샘플 복사 후 값 수정)
cp terraform.tfvars.example terraform.tfvars

# 3. 변경 확인 → 4. 배포
terraform plan
terraform apply

# 5. 로컬 kubeconfig 갱신
aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>
```

- `terraform.tfvars`(및 `*.auto.tfvars`)는 예약된 파일명이라 **자동 로드**됨. `.gitignore` 제외라 민감값 넣기 안전.
- 다른 파일명은 `-var-file="prod.tfvars"`, 특정 값만 덮어쓸 땐 `-var="cluster_name=..."`.

## 🛡️ 기존 시스템 영향도

기존 VPC/서브넷을 지정(`vpc_id` 등)해, **같은 네트워크의 기존 클러스터 옆에 배포할 때** 확인용.

> **필수** — `terraform apply` 전 `terraform plan`에서 **`0 to destroy` (replace 없음)** 확인. destroy/replace가 뜨면 멈추고 점검.

```bash
# 1차 필터: 아무것도 안 나오고 'Plan: N to add, 0 to change, 0 to destroy'면 안전
terraform plan -no-color | grep -E 'Plan:|will be destroyed|will be replaced'
```
> grep은 1차 필터일 뿐. 처음 배포나 뭔가 걸리면 전체 `plan` 출력을 눈으로 확인할 것.

- ✅ 기존 VPC/서브넷은 **참조만** 하고 state로 관리 안 함 → 수정·삭제 대상 아님
- ✅ 생성물은 전부 `cluster_name` 접두사 **신규 리소스** → 이름 충돌 없음
- ✅ EKS가 기존 서브넷에 `kubernetes.io/cluster/<name>=shared` 태그를 **추가**하지만 기존 태그·동작은 유지
- ⚠️ 서브넷 여유 IP만 충분하면 됨 (신규 노드/파드가 IP를 나눠 씀)

## ⚠️ 주의 사항

- **비용** — EKS(시간당 ~$0.10), NAT Gateway, EC2, KMS 키 과금. 테스트 후 `terraform destroy` 필수.
- **NAT Gateway** — 비용용 `single_nat_gateway = true`. 운영은 가용성 위해 `false`(AZ별) 권장.
- **IAM 권한** — 실행 주체에 VPC·EKS 생성 권한 필요 (최소 `AdministratorAccess` 상응).
- **상태 관리** — `terraform.tfstate` 로컬 생성. 협업 시 S3 + DynamoDB 원격 백엔드 권장.
- **민감 정보** — `terraform.tfvars`·`*.tfstate`는 git 제외. 민감값은 이 파일 또는 `TF_VAR_xxx`로만.
- **콘솔 관리 시 drift** — 배포 후 콘솔에서 바꾸면 state와 어긋남. 이후 `apply`는 코드 기준으로 되돌리므로 주의.

## 🧹 리소스 삭제

state가 남아 있으면 한 줄로 제거됨.
```bash
terraform destroy
```

<details>
<summary><b>state를 버린 경우 — 콘솔/CLI 수동 삭제 참고</b></summary>

모든 이름은 `cluster_name` 기반. **아래 순서(의존성)대로** 삭제.

1. **노드** — Managed Node Group(`<name>-main`) → IAM 역할(`<name>-main-node`)·정책 → Launch Template
2. **애드온** — CoreDNS, kube-proxy, VPC CNI (노드그룹과 함께 정리됨)
3. **컨트롤 플레인** — EKS 클러스터 → 클러스터 IAM 역할 → 보안 그룹
4. **인증/권한** — OIDC 프로바이더(IRSA), Access Entry·정책 연결
5. **로그/암호화** — CloudWatch 로그 그룹(`/aws/eks/<name>/cluster`), KMS 키·별칭
6. **네트워크** (신규 생성 시) — NAT → 서브넷 → IGW → 라우팅 테이블 → VPC

**⚠️ 숨은 리소스 (남으면 과금·삭제 차단)**
- **EIP** — NAT 삭제해도 탄력적 IP는 남아 과금. 별도 해제.
- **로드밸런서·ENI** — `Service type=LoadBalancer` 썼다면 AWS 생성 ELB·SG가 남아 VPC 삭제 차단.
- **KMS 키** — 즉시 삭제 안 되고 7~30일 대기 상태 전환.

</details>
