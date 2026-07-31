# 앱 ↔ Kubernetes 호환성

apps/의 Helm 차트·관련 파일이 각 Kubernetes 버전에서 어떤 버전이었는지 기록.
**새 K8s로 올릴 때 맨 위 빈칸 섹션을 채우고, 그 위에 새 빈칸을 다시 만든다.** 아래 과거 기록은 보존.

## 업그레이드 절차

1. 각 컴포넌트 호환 하한을 출처에서 재확인.
   - Karpenter: karpenter.sh/docs/upgrading/compatibility
   - LB Controller: github.com/kubernetes-sigs/aws-load-balancer-controller/releases
2. `helm pull`로 새 버전 받고 옛 `.tgz` 삭제. LB 정책 파일도 새 버전으로 교체.
3. 아래 빈칸 섹션을 채우고, 그 위에 다음 업그레이드용 빈칸을 새로 만든다.

> 파일명엔 컴포넌트 자기 버전만 박는다. K8s 버전은 파일명에 넣지 않음(호환이 범위라 1:1이 아님) — K8s 기준 호환성은 이 문서로만 관리.

---

## K8s _.__  (미정, 다음 업그레이드)

| 컴포넌트 | 버전 | K8s 호환 하한 | 파일 | 출처 |
|---------|------|-------------|------|------|
| Karpenter | | | | karpenter.sh 호환 매트릭스 |
| LB Controller | | | | github releases |
| LB Controller IAM 정책 | | (앱과 동일) | | 앱 저장소 iam_policy.json |

---

## K8s 1.36  (2026-07, 현재)

| 컴포넌트 | 버전 | K8s 1.36 호환 하한 | 파일 | 출처 |
|---------|------|-----------------|------|------|
| Karpenter | 1.14.0 | **>= 1.13** | `karpenter/karpenter-1.14.0.tgz` | karpenter.sh 호환 매트릭스 |
| LB Controller | 3.4.2 | 1.22+ | `aws-lb-controller/aws-load-balancer-controller-3.4.2.tgz` | github releases |
| LB Controller IAM 정책 | v3.4.2 | (앱과 동일) | `../infra/modules/eks-stack/official-iam-policy-for-lb-controller-v3.4.2.json` | 앱 저장소 iam_policy.json |

> Karpenter 호환은 **범위**다(1.14는 K8s 1.30~1.36 모두 지원). 표의 "하한"은 1.36 기준 최소 버전.
