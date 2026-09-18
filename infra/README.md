# Terraform

AWS基盤を4つの独立したroot moduleで管理します。Terraform workspaceは使用しません。

| directory | 責務 | state key |
| --- | --- | --- |
| `bootstrap` | remote state用S3 bucket | `bootstrap/terraform.tfstate` |
| `foundation` | GitHub OIDCとTerraform Plan role | `foundation/terraform.tfstate` |
| `environments/dev` | 短時間の実動作検証環境 | `environments/dev/terraform.tfstate` |
| `environments/prod-reference` | 本番想定のplan専用環境 | `environments/prod-reference/terraform.tfstate` |

`modules/network`はVPC、subnet、route table、NAT Gatewayを担当し、`modules/container_platform`はECR、ALB、ECS、CloudWatchを担当します。環境rootはmoduleを呼び出し、NAT Gateway数、ECS task数、Fargate size、log保持期間、削除保護の差分だけを定義します。

すべてのS3 backendで`use_lockfile = true`を使用します。bootstrapとfoundationは通常の環境destroyから分離します。AWS account ID、state bucket名、認証情報はGitへ保存せず、実行時に渡します。

GitHub Actionsでは、全root moduleのformat、validate、TFLint、Trivy config scanを実行します。`dev`と`prod-reference`のplanはGitHub OIDCの短期認証情報を使い、plan fileやstateをartifactへ保存しません。

Plan roleはcaller identityの確認と、`dev`・`prod-reference`のstate読取・lock操作を許可します。環境resourceを追加した後も、PRの実行結果で不足が確認されたAWSサービスの読取権限だけを追加します。

Phase 5でVPC、NAT Gateway、ALB、ECS、ECR、CloudWatch Alarmをコード化します。`dev`は短時間の検証だけでapplyし、`prod-reference`は原則planだけを実行します。
