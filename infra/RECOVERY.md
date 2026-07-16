# Terraform state復旧手順

この手順はbootstrapまたはfoundationの作業directory、S3 state、Terraform管理情報を失った場合に使用します。通常の初期化やplanは[README](README.md)を参照してください。

## 前提

- AWS SSOで対象accountへログインしている
- `AWS_PROFILE`と`TF_VAR_aws_account_id`を確認している
- 対象stateを操作する人が1人だけである
- `.tflock`が残っている場合は、実行中のTerraformがないことを確認してから原因を調査する
- stateには秘密値が含まれる可能性があるため、backupをGitへ追加しない

```powershell
$env:AWS_PROFILE = "cdk-dev"
$env:TF_VAR_aws_account_id = aws sts get-caller-identity --query Account --output text
$env:TF_STATE_BUCKET = "aws-production-web-platform-tfstate-$env:TF_VAR_aws_account_id-ap-northeast-1"
```

## 1. Local作業directoryだけを失った場合

repositoryを取得し、対象root moduleをS3 backendで再初期化します。

```powershell
cd infra/bootstrap
terraform init -backend-config="bucket=$env:TF_STATE_BUCKET"
terraform state list
terraform plan -input=false -no-color
```

foundationの場合は`infra/foundation`、環境の場合は`infra/environments/dev`または`infra/environments/prod-reference`で同じ手順を実行します。

`terraform state list`で管理対象が表示され、planが`No changes`なら復旧完了です。

## 2. S3 stateの現行versionが壊れた場合

最初に、取得可能な現行stateを退避します。

```powershell
terraform state pull | Out-File -Encoding utf8 state-backup.json
```

S3 versioningから復元候補を確認します。`STATE_KEY`は対象root moduleのkeyへ置き換えます。

```powershell
$env:STATE_KEY = "foundation/terraform.tfstate"
aws s3api list-object-versions `
  --bucket $env:TF_STATE_BUCKET `
  --prefix $env:STATE_KEY
```

復元するversionを一時ファイルへ取得します。

```powershell
aws s3api get-object `
  --bucket $env:TF_STATE_BUCKET `
  --key $env:STATE_KEY `
  --version-id "復元対象のVersionId" `
  restored.tfstate
```

内容と対象keyを再確認した後、過去versionを新しい現行versionとして書き戻します。

```powershell
aws s3api put-object `
  --bucket $env:TF_STATE_BUCKET `
  --key $env:STATE_KEY `
  --body restored.tfstate `
  --server-side-encryption AES256
```

再初期化後にstateと差分を確認します。

```powershell
terraform init -reconfigure -backend-config="bucket=$env:TF_STATE_BUCKET"
terraform state list
terraform plan -input=false -no-color
```

復旧確認後、一時的に作成した`state-backup.json`と`restored.tfstate`を安全に削除します。

## 3. Bootstrap stateを完全に失った場合

S3 bucket自体が残っている場合は、新規作成せず既存resourceを空のremote stateへimportします。

```powershell
terraform init -reconfigure -backend-config="bucket=$env:TF_STATE_BUCKET"
terraform import aws_s3_bucket.terraform_state $env:TF_STATE_BUCKET
terraform import aws_s3_bucket_ownership_controls.terraform_state $env:TF_STATE_BUCKET
terraform import aws_s3_bucket_server_side_encryption_configuration.terraform_state $env:TF_STATE_BUCKET
terraform import aws_s3_bucket_versioning.terraform_state $env:TF_STATE_BUCKET
terraform import aws_s3_bucket_public_access_block.terraform_state $env:TF_STATE_BUCKET
terraform import aws_s3_bucket_policy.require_tls $env:TF_STATE_BUCKET
terraform plan -input=false -no-color
```

import後のplanが`No changes`になるまで、source codeとAWS実体の差を確認します。

## 4. Foundation stateを完全に失った場合

OIDC providerとPlan roleがAWSに残っている場合は、`infra/foundation`を初期化してimportします。

```powershell
$oidcArn = "arn:aws:iam::$env:TF_VAR_aws_account_id`:oidc-provider/token.actions.githubusercontent.com"
$roleName = "aws-production-web-platform-terraform-plan"

terraform init -reconfigure -backend-config="bucket=$env:TF_STATE_BUCKET"
terraform import aws_iam_openid_connect_provider.github_actions $oidcArn
terraform import aws_iam_role.terraform_plan $roleName
terraform import aws_iam_role_policy.terraform_plan_state "$roleName`:TerraformPlanStateAccess"
terraform import aws_iam_role_policy_attachment.terraform_plan_view_only "$roleName/arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
terraform plan -input=false -no-color
```

import後のplanが`No changes`になるまで、source codeとAWS実体の差を確認します。

## 5. State bucket自体を失った場合

bucket名は同じaccount内で再利用できるとは限りません。S3 versioningもbucket削除後は利用できないため、外部backupがなければ各AWS resourceを調査してimportする必要があります。

この状況を避けるため、state bucketには`prevent_destroy`と`force_destroy = false`を設定し、通常の環境destroyから分離しています。state bucketを削除するのは、全環境とfoundationを廃止し、必要なstate backupを別の安全な場所へ保管した後だけです。
