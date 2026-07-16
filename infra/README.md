# Terraform

AWS基盤を4つの独立したroot moduleで管理します。Terraform workspaceは使用しません。

| directory | 責務 | state key |
| --- | --- | --- |
| `bootstrap` | remote state用S3 bucket | `bootstrap/terraform.tfstate` |
| `foundation` | GitHub OIDCとTerraform Plan role | `foundation/terraform.tfstate` |
| `environments/dev` | 短時間の実動作検証環境 | `environments/dev/terraform.tfstate` |
| `environments/prod-reference` | 本番想定のplan専用環境 | `environments/prod-reference/terraform.tfstate` |

すべてのS3 backendで`use_lockfile = true`を使用します。bootstrapとfoundationは通常の環境destroyから分離します。AWS account IDとstate bucket名はGitへ保存せず、実行時に渡します。

GitHub Actionsでは、全root moduleのformat、validate、TFLint、Trivy config scanを実行します。`dev`と`prod-reference`のplanはGitHub OIDCの短期認証情報を使い、plan fileをartifactへ保存しません。
