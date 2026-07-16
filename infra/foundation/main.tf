locals {
  state_bucket_name = "${var.project_name}-tfstate-${var.aws_account_id}-${var.aws_region}"
  environment_state_keys = [
    "environments/dev/terraform.tfstate",
    "environments/prod-reference/terraform.tfstate",
  ]
  environment_lock_keys = [for key in local.environment_state_keys : "${key}.tflock"]
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]
}

data "aws_iam_policy_document" "terraform_plan_assume_role" {
  statement {
    sid     = "GitHubActionsOidc"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository}:pull_request",
        "repo:${var.github_repository}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "terraform_plan" {
  name                 = "${var.project_name}-terraform-plan"
  description          = "View-only role for Terraform plans from GitHub Actions."
  assume_role_policy   = data.aws_iam_policy_document.terraform_plan_assume_role.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "terraform_plan_view_only" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

data "aws_iam_policy_document" "terraform_plan_state" {
  statement {
    sid       = "ReadStateBucketMetadata"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${local.state_bucket_name}"]
  }

  statement {
    sid       = "ListEnvironmentState"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.state_bucket_name}"]

    condition {
      test     = "StringEquals"
      variable = "s3:prefix"
      values   = concat(local.environment_state_keys, local.environment_lock_keys)
    }
  }

  statement {
    sid     = "ReadEnvironmentState"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      for key in local.environment_state_keys : "arn:aws:s3:::${local.state_bucket_name}/${key}"
    ]
  }

  statement {
    sid    = "ManageEnvironmentStateLocks"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      for key in local.environment_lock_keys : "arn:aws:s3:::${local.state_bucket_name}/${key}"
    ]
  }
}

resource "aws_iam_role_policy" "terraform_plan_state" {
  name   = "TerraformPlanStateAccess"
  role   = aws_iam_role.terraform_plan.id
  policy = data.aws_iam_policy_document.terraform_plan_state.json
}
