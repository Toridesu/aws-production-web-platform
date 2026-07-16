terraform {
  backend "s3" {
    key          = "environments/prod-reference/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
