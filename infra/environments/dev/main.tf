data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

check "account_and_region_guard" {
  assert {
    condition = (
      data.aws_caller_identity.current.account_id == var.aws_account_id
      && data.aws_region.current.region == var.aws_region
    )
    error_message = "The authenticated AWS account or region does not match the configured environment."
  }
}
