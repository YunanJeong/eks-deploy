# AWS EKS Deployment with Terraform

Terraform으로 AWS에 EKS 클러스터 + VPC를 구축하는 IaC 프로젝트.
AWS 공식 모듈(VPC, EKS) 기반이며, `vpc_id` 지정 시 **기존 네트워크에 붙고** 비우면 **전용 VPC를 신규 생성**함.

> ⚠️ **기존 클러스터와 네트워크를 공유해 배포한다면** apply 전에 반드시 `terraform plan`에서 **`0 to destroy` / replace 없음**을 확인할 것.

---

## 📂 프로젝트 구조

```
eks-deploy/
├── infra/                              # 인프라 (Terraform)
│   ├── modules/eks-cluster/            # 공유 모듈 = 실제 리소스 코드
│   │   ├── eks.tf                      # EKS 클러스터, Managed Node Group, 애드온
│   │   ├── vpc.tf                      # 네트워크(기존 참조 or 신규 생성)
│   │   ├── iam.tf                      # Pod Identity 역할·연결(Karpenter/CNI/EBS/LB)
│   │   ├── variables.tf                # 입력 변수 선언
│   │   ├── outputs.tf                  # 출력값
│   │   ├── versions.tf                 # terraform/provider 요구사항
│   │   └── official-iam-policy-for-lb-controller-*.json
│   └── envs/                           # 환경별 진입점 (환경 = 디렉토리)
│       ├── dev/
│       │   ├── main.tf                 # provider + 모듈 호출
│       │   ├── backend.tf              # S3 state (key=eks/dev)
│       │   ├── variables.tf            # 모듈로 넘길 변수 선언
│       │   ├── outputs.tf              # 모듈 output 재노출
│       │   ├── terraform.tfvars        # 실제 값 (git 제외)
│       │   └── terraform.tfvars.example# 템플릿 (git 포함)
│       └── prod/                       # dev와 동일 구성 (backend key=eks/prod)
└── apps/                               # 앱 (Helm, 별도 배포 — 이 Terraform 범위 밖)
    ├── COMPATIBILITY.md                 # 앱 ↔ K8s 호환성 이력 (업그레이드 시 여기부터)
    ├── karpenter/                       # 차트(.tgz) + values.yaml + nodepool_nodeclass_guide.yaml(샘플)
    └── aws-lb-controller/               # 차트(.tgz) + values.yaml
```

> ### 📌 디렉토리 분리 원칙 (중요)
> - **코드는 `modules/eks-cluster`에 한 벌.** 각 env는 값만 다르게 이 모듈을 호출함 (중복 없음).
> - **환경 = 디렉토리 = state.** dev/prod가 물리적으로 분리돼 섞일 수 없음.
> - **환경 전환은 오직 `cd`.** `terraform workspace`나 `-backend-config` 전환 안 씀 — 폴더 이동이 곧 환경 전환.
> - 그래서 "지금 어느 환경?"은 **현재 경로(pwd)가 곧 답** → 실수로 다른 환경 건드릴 위험 원천 차단.

## 🏗️ 인프라 특징

| | |
|------|------|
| **유연한 네트워크** | `vpc_id` 미지정 시 전용 VPC 신규 생성, 지정 시 기존 네트워크에 붙음 |
| **네트워크 격리** | 노드는 프라이빗 서브넷, 외부 통신은 NAT 경유. LB용 퍼블릭 서브넷 별도. 3 AZ 분산 |
| **표준 구성** | 보안 그룹·IAM 자동 구성. 생성자에 Access Entry 관리자 권한 (KMS/CloudWatch 로그는 비활성) |
| **Pod Identity** | Karpenter·VPC CNI·EBS CSI·LB Controller용 IAM 역할을 Pod Identity로 연결 |
| **애드온** | vpc-cni·coredns·kube-proxy·pod-identity-agent·ebs-csi·metrics-server 등 관리형 애드온 |
| **일괄 태깅** | `default_tags`로 모든 리소스에 공통 태그 |
| **블루/그린** | `cluster_name`·`cluster_version`을 바꿔 신규 클러스터를 나란히 세움 |

### 보안그룹 3종 (자동 생성)

| 보안그룹 | 생성 주체 | 역할 |
|----------|-----------|------|
| `eks-cluster-sg-<name>-*` | AWS(EKS) 자동 | 컨트롤플레인 ENI에 붙음. self 전체 허용 규칙 보유. 우리 모듈은 노드엔 안 붙임(node SG 사용). 규칙 수정 불가 |
| `<name>-cluster-*` | EKS 모듈 | 컨트롤플레인(API 서버) 쪽. 노드→API(443) 등 커스텀 규칙용. 콘솔 "추가 보안 그룹" |
| `<name>-node-*` | EKS 모듈 | 노드에 붙음. 노드↔노드(DNS 53·**ephemeral=파드 간 통신**) + 컨트롤플레인→노드(kubelet 10250·웹훅) |

- 노드그룹 노드에는 **node SG만** 붙는다(primary는 기본 미부착). node SG의 self 규칙으로 노드 간 통신이 커버됨.
- **노드 간 파드 통신은 `ephemeral(1025-65535)` self 규칙으로 허용된다.** (DNS만 53으로 별도)
- 모듈이 포트별로 세분화한 이유는 최소 권한(primary의 self 전체 허용보다 공격면 축소).

## 🚀 사용 방법

**사전 요구사항** — [Terraform CLI](https://developer.hashicorp.com/terraform/downloads), [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 + `aws configure`

작업할 **환경 디렉토리로 이동**해서 진행함 (dev 예시, prod도 동일):

```bash
cd infra/envs/dev                               # 환경 = 디렉토리 (prod도 동일)
cp terraform.tfvars.example terraform.tfvars    # 값 수정 (최소 cluster_name)
terraform init -backend-config="bucket=<버킷명>"   # 옵션 없이 치면 대화형으로 물어봄
terraform plan
terraform apply
aws eks update-kubeconfig --region <AWS_REGION> --name <CLUSTER_NAME>   # kubeconfig 갱신
```

- **환경 전환은 `cd`로 끝** — 폴더가 곧 환경·state라 헷갈릴 일 없음.
- **state 버킷명은 보안상 코드(`backend.tf`)에 없음** → 위처럼 init 시 지정(옵션) 또는 대화형 입력. 한 번 init하면 이후엔 불필요.
- `terraform.tfvars`는 자동 로드·`.gitignore` 제외. 커밋 대상은 `.example`뿐.

## ⚙️ 설정 참고

전체 변수와 기본값은 **`terraform.tfvars.example`** 에 주석과 함께 정리돼 있음. 아래는 알아둘 핵심만.

- **`cluster_name`만 필수** — 나머지는 `variables.tf` 기본값 사용 (생략 가능).
- **노드 방식** — EKS Managed Node Group으로 기본 노드를 구성. **EKS Auto Mode는 추가 비용이 발생하므로 사용하지 않고**, 비용 절감을 위해 **Karpenter를 Helm 차트로 직접 설치·관리**함 (이 Terraform 범위 밖).
- **인증 모드** — 기본 `API_AND_CONFIG_MAP` (Access Entry + 레거시 `aws-auth` ConfigMap 병행). 레거시 앱 없으면 `API`로 좁힐 수 있음.
- **엔드포인트** — 원격 `kubectl`용 퍼블릭 활성화. 운영에선 `cluster_endpoint_public_access_cidrs`로 접근 IP를 좁힐 것.
- **KMS/로그 비활성** — Secret 암호화 KMS·컨트롤플레인 CloudWatch 로그는 끔(`kms:*`/`logs:*` 권한 불필요). 컴플라이언스 필요 시 활성화.

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
- ✅ 기존 서브넷에 `kubernetes.io/cluster/<name>` 등 태그가 **추가**될 수 있으나 기존 태그·동작은 유지(태그는 더해질 뿐 덮어쓰지 않음)
- ⚠️ 서브넷 여유 IP만 충분하면 됨 (신규 노드/파드가 IP를 나눠 씀)

## ⚠️ 주의 사항

- **비용** — EKS 클러스터(시간당 ~$0.10), NAT Gateway, EC2 노드에 과금. 테스트 후 `terraform destroy` 필수.
- **NAT Gateway** — 비용용 `single_nat_gateway = true`. 운영은 가용성 위해 `false`(AZ별) 권장.
- **IAM 권한** — 실행 주체에 VPC·EKS 생성 권한 필요 (최소 `AdministratorAccess` 상응).
- **상태 관리** — 각 env `backend.tf`로 S3에 state 저장(env별 key 분리). `use_lockfile=true`로 S3 자체 잠금(DynamoDB 불필요). 버킷명은 코드에 없고 init 시 주입(public 노출 방지).
- **민감 정보** — `terraform.tfvars`·`*.tfstate`는 git 제외. 민감값은 이 파일 또는 `TF_VAR_xxx`로만.
- **콘솔 관리 시 drift** — 배포 후 콘솔에서 바꾸면 state와 어긋남. 이후 `apply`는 코드 기준으로 되돌리므로 주의.

## 🧹 리소스 삭제

state가 남아 있으면 한 줄로 제거됨.
```bash
terraform destroy
```

<details>
<summary><b>state를 버린 경우 — 콘솔/CLI 수동 삭제</b></summary>

모든 이름은 `cluster_name` 기반. **아래 순서(의존성)대로** 삭제.

1. **노드** — Managed Node Group(`<name>-main`) → 노드 IAM 역할(`<name>-MainNodeGroup`)·정책 → Launch Template
2. **애드온** — vpc-cni, coredns, kube-proxy, pod-identity-agent, ebs-csi, metrics-server (클러스터 삭제 시 함께 사라짐. 단 연결된 IAM 역할은 4번에서 별도 삭제)
3. **컨트롤 플레인** — EKS 클러스터 → 클러스터 IAM 역할(`<name>-cluster-` 접두사) → 보안 그룹(`<name>-cluster-*`·`<name>-node-*`)
4. **앱용 IAM 역할** (Pod Identity, 이 프로젝트가 생성)
   - `<name>-KarpenterController`, `<name>-KarpenterNode`, Karpenter SQS 큐(`Karpenter-<name>`)
   - `<name>-AmazonEKSPodIdentityAmazonVPCCNIRole`, `<name>-AmazonEKSPodIdentityAmazonEBSCSI`, `<name>-AmazonEKSLoadBalancerControllerRole`
   - → 각 연결된 정책
5. **인증/권한** — OIDC 프로바이더(IRSA), Access Entry·정책 연결
6. **네트워크** (신규 생성 시) — NAT → 서브넷 → IGW → 라우팅 테이블 → VPC

IAM 역할 목록은 apply 하단의 `iam_roles_base`(기본 생성) / `iam_roles_app`(앱용) output으로 확인 가능.

**⚠️ 숨은 리소스 (남으면 과금·삭제 차단)**
- **EIP** — NAT 삭제해도 탄력적 IP는 남아 과금. 별도 해제.
- **로드밸런서·ENI** — `Service type=LoadBalancer` 썼다면 AWS 생성 ELB·SG가 남아 VPC 삭제 차단.
- **KMS 키** — (활성화한 경우) 즉시 삭제 안 되고 7~30일 대기 상태 전환.

</details>
