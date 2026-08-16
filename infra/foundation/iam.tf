data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    sid    = "GitHubActionsAssumeRole"
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = local.github_plan_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_plan_read" {
  statement {
    sid    = "ReadFoundationIam"
    effect = "Allow"

    actions = [
      "iam:GetOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListRoleTags"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "GetCallerIdentity"
    effect = "Allow"

    actions = [
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_plan_read" {
  name   = "${local.github_plan_role_name}-read"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_read.json
}

data "aws_iam_policy_document" "github_plan_state" {
  statement {
    sid    = "ListFoundationState"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      local.state_bucket_arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "foundation/terraform.tfstate",
        "foundation/terraform.tfstate.tflock"
      ]
    }
  }

  statement {
    sid    = "ReadWriteFoundationState"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      local.foundation_state_arn
    ]
  }

  statement {
    sid    = "ManageFoundationLock"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      local.foundation_lock_arn
    ]
  }

  statement {
    sid    = "GetBucketLocation"
    effect = "Allow"

    actions = [
      "s3:GetBucketLocation"
    ]

    resources = [
      local.state_bucket_arn
    ]
  }
}

resource "aws_iam_role_policy" "github_plan_state" {
  name   = "${local.github_plan_role_name}-state"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_state.json
}