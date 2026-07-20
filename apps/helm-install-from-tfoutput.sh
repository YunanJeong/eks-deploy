#!/usr/bin/env bash
#======================================================================
# helm-install-from-tfoutput - Terraform output을 읽어 Helm 앱을 일괄 자동 설치
#   - infra(Terraform) output -> Helm 값(--set)으로 자동 주입, 수동 치환 오타 방지.
#   - 정적 설정은 각 values.yaml(-f), 동적 값(cluster_name 등)만 --set으로 덮음.
#   - 설치 순서 강제: LB CRD -> LB Controller -> Karpenter.
#   - NodePool/EC2NodeClass는 클러스터·서브넷마다 달라 여기서 자동 적용하지 않음
#     (nodepool_nodeclass_guide.yaml 참고해 수동 작성/적용).
#
# 사용:
#   ./helm-install-from-tfoutput.sh dev        # infra/envs/dev 의 output 사용
#   ./helm-install-from-tfoutput.sh prod
#======================================================================
set -euo pipefail

ENV="${1:-}"
if [[ -z "$ENV" ]]; then
  echo "사용법: ./helm-install-from-tfoutput.sh <env>   (예: ./helm-install-from-tfoutput.sh dev)" >&2
  exit 1
fi

APPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$APPS_DIR/../infra/envs/$ENV"

if [[ ! -d "$ENV_DIR" ]]; then
  echo "환경 디렉토리 없음: $ENV_DIR" >&2
  exit 1
fi

# 받아둔 로컬 차트 (COMPATIBILITY.md의 버전과 일치)
LB_DIR="$APPS_DIR/aws-lb-controller"
KARPENTER_DIR="$APPS_DIR/karpenter"
LB_CHART="$LB_DIR/aws-load-balancer-controller-3.4.2.tgz"
KARPENTER_CHART="$KARPENTER_DIR/karpenter-1.14.0.tgz"

for c in "$LB_CHART" "$KARPENTER_CHART"; do
  [[ -f "$c" ]] || { echo "차트 없음: $c (helm pull 먼저)" >&2; exit 1; }
done

#----------------------------------------------------------------------
# 1. Terraform output 읽기 (실물 값은 여기서만 메모리에 담김, git 미기록)
#----------------------------------------------------------------------
echo "==> [$ENV] Terraform output 읽는 중..."
pushd "$ENV_DIR" >/dev/null

CLUSTER_NAME="$(terraform output -raw cluster_name)"
AWS_REGION="$(terraform output -raw aws_region)"
VPC_ID="$(terraform output -raw vpc_id)"
KARPENTER_QUEUE="$(terraform output -json karpenter | jq -r .queue_name)"
KARPENTER_SA="$(terraform output -json karpenter | jq -r .service_account)"

popd >/dev/null

echo "    cluster_name : $CLUSTER_NAME"
echo "    region       : $AWS_REGION"
echo "    vpc_id       : $VPC_ID"
echo "    karpenter 큐 : $KARPENTER_QUEUE"
echo ""
read -r -p "위 클러스터에 설치를 진행할까요? [y/N] " ans
[[ "$ans" == "y" || "$ans" == "Y" ]] || { echo "취소됨."; exit 0; }

# kubeconfig가 이 클러스터를 가리키는지 확인 (엉뚱한 클러스터 방지)
echo "==> kubeconfig 갱신"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

#----------------------------------------------------------------------
# 2. AWS Load Balancer Controller
#    - CRD는 차트가 자동 설치 안 하므로 먼저 적용
#    - 정적 설정은 values.yaml(-f), 동적 값만 --set으로 덮음
#----------------------------------------------------------------------
echo "==> LB Controller CRD 적용 (받아둔 차트 v3.4.2 내장 CRD로 버전 일치)"
# helm은 upgrade 시 CRD를 자동 적용하지 않으므로 수동 적용. ?ref=master 대신 차트 내장본 사용.
tar -xzOf "$LB_CHART" aws-load-balancer-controller/crds/crds.yaml | kubectl apply -f -

echo "==> LB Controller 설치 (Helm)"
# --wait: webhook이 준비될 때까지 대기 후 다음(Karpenter)으로 넘어감.
#   (안 기다리면 LB Controller webhook 미준비 상태에서 Karpenter 설치가 실패)
echo "    파드 Ready(webhook 준비)까지 보통 1~2분 대기합니다..."
helm upgrade --install aws-load-balancer-controller "$LB_CHART" \
  -n kube-system \
  -f "$LB_DIR/values.yaml" \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --wait --timeout 5m

#----------------------------------------------------------------------
# 3. Karpenter
#    - 정적 설정(resources 등)은 values.yaml(-f), 동적 값만 --set으로 덮음
#----------------------------------------------------------------------
echo "==> Karpenter 설치 (Helm)"
helm upgrade --install karpenter "$KARPENTER_CHART" \
  -n kube-system \
  -f "$KARPENTER_DIR/values.yaml" \
  --set settings.clusterName="$CLUSTER_NAME" \
  --set settings.interruptionQueue="$KARPENTER_QUEUE" \
  --set serviceAccount.name="$KARPENTER_SA"

#----------------------------------------------------------------------
# 완료 안내
#----------------------------------------------------------------------
cat <<EOF

==> 설치 완료.
확인:
  kubectl get deploy -n kube-system aws-load-balancer-controller
  kubectl get deploy -n kube-system karpenter

다음 단계 (수동): NodePool / EC2NodeClass 적용
  karpenter/nodepool_nodeclass_guide.yaml 을 클러스터·서브넷에 맞게 작성 후:
    kubectl apply -f <작성한 파일>
  role=$CLUSTER_NAME-KarpenterNode / 서브넷 discovery 태그 지정 필요.
EOF
