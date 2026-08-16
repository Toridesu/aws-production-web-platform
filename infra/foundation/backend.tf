terraform {
  backend "s3" {
    key          = "foundation/terraform.tfstate"
    use_lockfile = true
  }
}
