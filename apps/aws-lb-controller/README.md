# AWS Load Balancer Controller

Ingress → ALB, `Service type=LoadBalancer` → NLB 를 프로비저닝하는 컨트롤러.
Helm으로 설치하며 이 Terraform 범위 밖이다.

## 전제 (Terraform 쪽에서 이미 준비됨)

- **Pod Identity 역할**: `iam.tf`가 `<cluster_name>-AmazonEKSLoadBalancerControllerRole`
  역할 + 공식 IAM 정책 + association (`kube-system` / SA `aws-load-balancer-controller`)을
  **완비**해 둠. (Karpenter와 달리 권한 정책까지 부착 완료)
- **pod-identity-agent 애드온**: `eks.tf`에서 설치됨 (association 작동 전제).

## 버전

- LB Controller **v2.x** (Terraform의 정책 파일 버전과 맞출 것:
  `infra/modules/eks-cluster/official-iam-policy-for-lb-controller-v2.14.1.json`).
  Helm 차트 버전을 올리면 그 정책 파일도 같은 버전으로 갱신.

## 설치

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=<cluster_name> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller
```

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
