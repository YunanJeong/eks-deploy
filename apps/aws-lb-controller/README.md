# AWS Load Balancer Controller

Ingress → ALB, `Service type=LoadBalancer` → NLB 를 프로비저닝하는 컨트롤러.
Helm으로 설치하며 이 Terraform 범위 밖이다.

**파일**: `aws-load-balancer-controller-3.4.2.tgz`(차트) · `values.yaml`(Helm 값)

## 전제 (Terraform 쪽에서 이미 준비됨)

- **Pod Identity 역할**: `iam.tf`가 `<cluster_name>-AmazonEKSLoadBalancerControllerRole`
  역할 + 공식 IAM 정책 + association (`kube-system` / SA `aws-load-balancer-controller`)을
  **완비**해 둠. (Karpenter와 달리 권한 정책까지 부착 완료)
- **pod-identity-agent 애드온**: `eks.tf`에서 설치됨 (association 작동 전제).

## 버전

- LB Controller **v3.4.2** (차트 `aws-load-balancer-controller-3.4.2.tgz`로 받아둠).
  K8s 1.22+ 지원이라 1.36 호환. Terraform 정책 파일도 같은 버전:
  `infra/modules/eks-cluster/official-iam-policy-for-lb-controller-v3.4.2.json`.
- **v3부터 Helm 차트 버전 = 앱 버전** (v2.x 시절엔 차트 v1.x로 어긋났음).
- **CRD**: helm이 `install` 시엔 자동 적용하나 `upgrade` 시엔 안 함. 우리 스크립트는
  `upgrade --install`이라 차트 내장 CRD를 매번 명시 적용(버전 일치·재현성 확보).

## 설치

> **간편 경로**: `apps/helm-install-from-tfoutput.sh <env>` 가 Terraform output을 읽어 LB Controller와
> Karpenter를 한 번에 설치한다. 아래는 그중 LB Controller 부분(CRD+설치)을 수동으로 하는 방법.

정적 설정은 `values.yaml`, 동적 값(clusterName·region·vpcId)은 `--set`으로 주입한다
(values.yaml의 `<>`는 그대로 두고 --set이 덮음). 값은 인프라 output에서:
`terraform output cluster_name` / `aws_region` / `vpc_id`.

```bash
# 1. CRD 먼저 적용 (helm은 upgrade 시 CRD 자동 적용 안 함). 차트 v3.4.2 내장 CRD 사용.
tar -xzOf aws-load-balancer-controller-3.4.2.tgz aws-load-balancer-controller/crds/crds.yaml | kubectl apply -f -

# 2. 받아둔 로컬 차트로 설치
helm upgrade --install aws-load-balancer-controller aws-load-balancer-controller-3.4.2.tgz \
  -n kube-system \
  -f values.yaml \
  --set clusterName=<cluster_name> --set region=<aws_region> --set vpcId=<vpc_id>
```
> 최신 재다운로드: `helm pull eks/aws-load-balancer-controller --version <버전>`
> (`helm repo add eks https://aws.github.io/eks-charts` 후)

- `serviceAccount.name=aws-load-balancer-controller` 는 `iam.tf` association과 일치 필수.
- **annotation 불필요**: Pod Identity 방식이라 SA에 `eks.amazonaws.com/role-arn`
  annotation을 넣지 않는다. (IRSA와 다른 점)
- SA는 생성되게만(`create=true`) 하면 association이 자동으로 권한을 연결한다.

## 확인

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller   # 2/2 Running
```

## 체크포인트

- SA 이름(`aws-load-balancer-controller`) = iam.tf association 값과 일치
- Helm 차트 버전 ↔ Terraform 정책 파일 버전 일치
- pod-identity-agent 애드온 Running
- (Ingress로 ALB 붙일 때) 퍼블릭 서브넷에 `kubernetes.io/role/elb` 태그 필요
