# Karpenter

노드 오토스케일링(비용 절감용). EKS Managed Node Group 위에서 동작하며, 파드 수요에
맞춰 EC2를 동적으로 프로비저닝/정리한다. Helm으로 설치하며 이 Terraform 범위 밖이다.

**파일**: `values.yaml`(Helm 값) · `nodepool.yaml`(NodePool + EC2NodeClass)

## 전제 (Terraform 쪽에서 이미 준비됨)

- **컨트롤러 IAM 역할 + 권한 정책 + SQS 큐 + 노드 역할 + association**: `karpenter.tf`의
  전용 서브모듈이 **전부 생성**해 둠 (모듈 v21은 v1 권한 정책이 기본이라 별도 설정 없이 부착됨).
  LB Controller와 달리 권한을 수동으로 붙일 필요 없음.
- **pod-identity-agent 애드온**: `eks.tf`에서 설치됨 (association 작동 전제).
- **discovery 태그는 서브넷과 보안그룹 딱 둘에만 필요**하다. (AMI는 alias로,
  노드 역할은 직접 지정하므로 태그 불필요) 그 보안그룹은 기본 노드그룹 노드가 쓰는
  node SG여야 Karpenter 노드도 컨트롤플레인·노드 간 통신이 동일하게 열린다.
- **보안그룹 discovery**: node SG에 `karpenter.sh/discovery=<cluster_name>` 태그가
  Terraform(eks.tf의 node_security_group_tags)으로 자동 등록됨. Karpenter 노드는 이
  node SG를 물려 기본 노드그룹과 동일한 통신 규칙을 갖는다.
- **서브넷 discovery**:
  - 신규 VPC 생성 시 → vpc.tf가 프라이빗 서브넷에 `karpenter.sh/discovery=<cluster_name>` 자동 등록.
  - 기존 VPC 사용 시 → Terraform이 태깅하지 않으므로, EC2NodeClass에서 기존 서브넷을
    태그(기존 클러스터 discovery 값)나 ID로 직접 지정한다.

## 버전

- Karpenter **v1.14.0** (차트 `karpenter-1.14.0.tgz`로 받아둠). K8s 1.36은 Karpenter
  `>= 1.13`을 요구하므로 이 버전이 호환된다. CRD: `NodePool`(`karpenter.sh/v1`),
  `EC2NodeClass`(`karpenter.k8s.aws/v1`).

## 설치 순서

준비값(인프라 apply 출력): `terraform output karpenter` → `queue_name`, `node_iam_role`, `service_account`.

### 1. Helm 설치

`values.yaml`의 `<>`(clusterName·interruptionQueue)를 채운 뒤 설치한다.

```bash
helm upgrade --install karpenter karpenter-1.14.0.tgz \
  --namespace kube-system \
  -f values.yaml
```
> 받아둔 로컬 차트(`karpenter-1.14.0.tgz`)로 설치. 최신 재다운로드:
> `helm pull oci://public.ecr.aws/karpenter/karpenter --version <버전>`
> `serviceAccount.name=karpenter` 는 `karpenter.tf` 서브모듈이 만든 Pod Identity
> association과 반드시 일치해야 권한이 연결된다. (annotation은 Pod Identity라 불필요)

### 2. NodePool / EC2NodeClass 적용

`nodepool.yaml`의 `<>`(role·서브넷 discovery 값)를 채운 뒤 적용한다.

```bash
kubectl apply -f nodepool.yaml
```
- `role` = `<cluster_name>-KarpenterNode` (node_iam_role 출력값)
- 서브넷 = 기존 서브넷의 discovery 태그값 또는 ID 직접 지정
- 보안그룹 = 인프라가 node SG에 붙인 `karpenter.sh/discovery=<cluster_name>`

## 체크포인트

- SA 이름(`karpenter`) = karpenter.tf 서브모듈 association 값과 일치
- node SG discovery 태그(`=cluster_name`)는 Terraform이 자동 등록. 서브넷은 NodeClass에서 직접 지정
- 컨트롤러 IAM 정책은 인프라 서브모듈이 부착 완료 (수동 부착 불필요)
- pod-identity-agent 애드온 Running
