#======================================================================
# prod state 백엔드 (S3)
#   - 버킷/DynamoDB(또는 use_lockfile)는 사전 생성 필요.
#   - bucket 이름은 실제 값으로 교체할 것 (계정ID/랜덤 섞어 예측 불가하게).
#   - dev와 같은 버킷을 쓰되 key로 분리함 (env별 독립 state).
#======================================================================

terraform {
  backend "s3" {
    bucket       = "CHANGE-ME-tfstate-bucket"
    key          = "eks/prod/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true # S3 자체 잠금 (DynamoDB 불필요, Terraform 1.10+)
  }
}
