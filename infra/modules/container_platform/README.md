# Container platform module

このmoduleは、`dev`と`prod-reference`で共有するコンテナ実行基盤を作成します。

作成するもの:

- scan-on-pushを有効にしたimmutableなECR repository
- 未tag imageと古いimageを整理するECR Lifecycle Policy
- ECS cluster
- CloudWatch Log Group
- ECR pullとCloudWatch Logsだけを許可するECS Task Execution Role
- 当初はアプリケーション権限を持たせないAPI Task Role
- 一時的なHTTP `/32`送信元制限を持つinternet-facing ALB
- ALB、ECS task、将来のRDS用Security Group
- health pathだけを転送し、それ以外を既定で403にするALB listener
- コンテナhealth checkを持つECS Fargate task definition
- private subnetにtaskを配置し、ALBへ登録するECS service
- ALB target error、unhealthy target、ECS CPU / memoryを対象にした基本CloudWatch Alarm

ECS taskはimmutableなECR image tagを使用し、実際のtoken検証を導入するまで`AUTH_MODE=deny-all`でAPI操作を拒否します。ローカル開発では従来どおり`AUTH_MODE=dev`を使用します。DatabaseとSecrets Managerの権限はPhase 6Aまで意図的に保留します。

`ecr_force_delete = true`は、破棄前提の`dev`検証だけで使用します。`prod-reference`ではimageを含むrepositoryを誤って削除しないよう、falseのままにします。
