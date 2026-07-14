#======================================================================
# dev state 백엔드 (S3)
#   - bucket은 public 노출 방지 위해 코드에 두지 않음. init 시 지정:
#       terraform init -backend-config="bucket=<버킷명>"   (옵션 방식)
#       terraform init                                      (대화형: 버킷명 물어봄)
#   - 버킷/잠금은 사전 생성 필요. dev/prod 같은 버킷을 key로 분리함.
#======================================================================

terraform {
  backend "s3" {
    # bucket = "my-tfstate-bucket"  # 코드에 두지 않음. init 시 주입하거나 대화형 입력.
    key          = "eks/dev/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true # S3 자체 잠금 (DynamoDB 불필요, Terraform 1.10+)
  }
}
