# Karpenter

노드 오토스케일링(비용 절감용). EKS Managed Node Group 위에서 동작하며, 파드 수요에
맞춰 EC2를 동적으로 프로비저닝/정리한다. Helm으로 설치하며 이 Terraform 범위 밖이다.

## 전제 (Terraform 쪽에서 이미 준비됨)

- **Pod Identity 역할**: `iam.tf`가 `<cluster_name>-Karpenter` 역할 + association
  (`kube-system` / SA `karpenter`)을 생성해 둠.
  ⚠️ 단, **컨트롤러 권한 정책은 아직 비어 있음** — 아래 IAM 정책 부여 단계 필요.
- **pod-identity-agent 애드온**: `eks.tf`에서 설치됨 (association 작동 전제).
- **보안그룹 discovery**: node SG에 `karpenter.sh/discovery=<cluster_name>` 태그가
  Terraform(eks.tf의 node_security_group_tags)으로 자동 등록됨. Karpenter 노드는 이
  node SG를 물려 기본 노드그룹과 동일한 통신 규칙을 갖는다.
- **서브넷 discovery**:
  - 신규 VPC 생성 시 → vpc.tf가 프라이빗 서브넷에 `karpenter.sh/discovery=<cluster_name>` 자동 등록.
  - 기존 VPC 사용 시 → Terraform이 태깅하지 않으므로, EC2NodeClass에서 기존 서브넷을
    태그(기존 클러스터 discovery 값)나 ID로 직접 지정한다.

## 버전

- Karpenter **v1.x** (설치 시점 최신 확인). CRD: `NodePool`(`karpenter.sh/v1`),
  `EC2NodeClass`(`karpenter.k8s.aws/v1`).

## 설치 순서

### 1. 컨트롤러 IAM 권한 부여

`<cluster_name>-Karpenter` 역할에 Karpenter 컨트롤러 정책을 붙인다. (버전마다 필요
권한이 달라 Terraform에 미리 박지 않음) 해당 버전의 공식 정책을 확인해 부착한다.

### 2. (선택) SQS 인터럽션 큐

Spot 중단·EC2 이벤트를 빠르게 처리하려면 인터럽션 큐(SQS)를 두고 컨트롤러에 연결한다.
기본 동작에 필수는 아니나 Spot 사용 시 권장.

### 3. Helm 설치

```bash
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version <버전> \
  --namespace kube-system \
  --set "serviceAccount.name=karpenter" \      # iam.tf association의 SA와 일치 필수
  --set "settings.clusterName=<cluster_name>" \
  --set "settings.interruptionQueue=<큐 이름>"  # 인터럽션 큐 쓸 때만
```
> `serviceAccount.name=karpenter` 는 `iam.tf`의 Pod Identity association과 반드시
> 일치해야 권한이 연결된다. (annotation은 Pod Identity라 불필요)

### 4. NodePool / EC2NodeClass 적용

```yaml
# EC2NodeClass — 노드 스펙·discovery
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata: { name: default }
spec:
  role: <노드 IAM 역할명>          # C-test-KarpenterNode (karpenter.tf 출력)
  subnetSelectorTerms:            # 기존 VPC 서브넷 - 기존 태그값 또는 ID로 직접 지정
    - tags: { karpenter.sh/discovery: <기존 클러스터 discovery 값> }
  securityGroupSelectorTerms:    # Terraform이 node SG에 붙인 태그 = cluster_name
    - tags: { karpenter.sh/discovery: <cluster_name> }
---
# NodePool — 스케일링/통합 정책
apiVersion: karpenter.sh/v1
kind: NodePool
metadata: { name: default }
spec:
  template:
    spec:
      nodeClassRef: { group: karpenter.k8s.aws, kind: EC2NodeClass, name: default }
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
```

## 체크포인트

- SA 이름(`karpenter`) = iam.tf association 값과 일치
- node SG discovery 태그(`=cluster_name`)는 Terraform이 자동 등록. 서브넷은 NodeClass에서 직접 지정
- 컨트롤러 역할에 IAM 정책 부착됨 (안 하면 EC2 생성 권한 없어 실패)
- pod-identity-agent 애드온 Running
