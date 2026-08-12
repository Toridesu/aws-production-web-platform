# infra

TerraformによるAWS基盤を配置します。

予定する構成:

- `bootstrap`: remote state用S3 bucket
- `modules`: 再利用可能なTerraform module
- `environments/dev`: 短時間の実動作検証環境
- `environments/prod-reference`: 本番想定のplan専用環境

実装はPhase 4以降で追加します。

