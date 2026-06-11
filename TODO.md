# TODO

> 状態: 計画確定 / 実装未開始

このファイルをプロジェクト全体の進捗管理に使用します。完了した項目は`[x]`へ変更し、各作業完了時に残作業も更新します。

## 共通ルール

- AWSリソースをapplyする前に、費用、最大稼働時間、destroy方法を確認する
- AWS検証セッションは最大5時間、税抜5米ドル以内を目標とする
- AWS検証セッション終了時に同日destroyと残存リソース確認を行う
- `prod-reference`は原則としてplanだけを実行する
- 実装作業後はコマンド、意味、手順、結果を1つの学習用Markdownへ記録する
- 個人情報、認証情報、plan file、学習用資料はGit管理しない

## Phase 0: 計画と設計判断

- [x] プロジェクトの目的と対象範囲を定義する
- [x] 所有者付きタスク管理APIとデータモデルを決定する
- [x] Cognito JWT認証を初期スコープへ含める
- [x] `dev`と`prod-reference`の役割と差分を決定する
- [x] private ECSの外向き通信方式を決定する
- [x] Terraform bootstrapとS3 lockfile方式を決定する
- [x] migrationとデプロイ順序を決定する
- [x] AWS検証セッションとコスト上限を決定する
- [x] セキュリティ・運用・コスト資料の重複を統合する

## Phase 1: リポジトリとローカル開発基盤

- [x] Gitリポジトリを初期化する
- [x] `.gitignore`とGit管理対象外の`private_docs`を設定する
- [x] Go、Docker、Terraformなどのversion方針を決定する
- [x] Go moduleと基本ディレクトリ構成を作成する
- [x] PostgreSQL用Docker Composeを作成する
- [x] ローカル用環境変数のsampleを作成する
- [x] READMEへローカル開発開始手順を追加する
- [x] Go `1.26.4`をインストールし、`go version`と`go mod edit -json`を確認する
- [x] PostgreSQLコンテナを起動し、health checkとSQL疎通成功を確認する

## Phase 2: Go API

- [ ] `/health/live`と`/health/ready`を実装する
- [ ] taskデータモデルとmigrationを実装する
- [ ] task CRUDを実装する
- [ ] Cognito JWT verifierを差し替え可能な構造で実装する
- [ ] `owner_sub`による所有者分離を実装する
- [ ] 入力検証と一貫したerror responseを実装する
- [ ] JSON構造化ログとrequest IDを実装する
- [ ] timeoutとgraceful shutdownを実装する
- [ ] unit test、integration test、認可testを追加する
- [ ] ローカルでAPI、PostgreSQL、migrationを検証する

## Phase 3: コンテナとCI基盤

- [ ] 非root・multi-stage Dockerfileを作成する
- [ ] Docker image buildとcontainer起動を確認する
- [ ] Go test、静的解析、依存関係検査workflowを作成する
- [ ] Docker image脆弱性検査を追加する
- [ ] Terraform検証workflowの土台を作成する
- [ ] GitHub branch protectionとEnvironment方針を文書化する

## Phase 4: Terraform bootstrapと環境構成

- [ ] `infra/bootstrap`を作成する
- [ ] state用S3 bucketの暗号化、versioning、Public Access Blockを実装する
- [ ] bootstrap stateをS3 backendへ移行する手順を作成する
- [ ] S3 backendの`use_lockfile = true`を設定する
- [ ] `infra/modules`を作成する
- [ ] `dev`と`prod-reference`の環境ディレクトリを作成する
- [ ] `allowed_account_ids`、共通tag、version制約を設定する
- [ ] `fmt`、`validate`、静的解析、`plan`を確認する

## Phase 5: ネットワークとECS基盤

- [ ] 2AZのPublic、Private Application、Private Database subnetを実装する
- [ ] Internet Gateway、NAT Gateway、route tableを実装する
- [ ] S3 Gateway Endpointを実装する
- [ ] Security Group参照による通信制御を実装する
- [ ] ECR、ALB、ECS cluster、ECS serviceを実装する
- [ ] ECS Task Execution RoleとAPI Task Roleを分離する
- [ ] CloudWatch Log Groupと保持期間を実装する
- [ ] `dev`と`prod-reference`の可用性差分をplanで確認する

### AWS検証セッションA

- [ ] 公式料金を確認し、5時間以内の概算費用を記録する
- [ ] 終了予定時刻とdestroy手順を確認する
- [ ] `dev`をapplyする
- [ ] ALB経由のGo health checkを確認する
- [ ] `dev`をdestroyする
- [ ] stateとAWS上の残存リソースを確認する

## Phase 6: RDS、Secrets、Cognito、HTTPS

- [ ] RDS PostgreSQLとDB subnet groupを実装する
- [ ] `dev`と`prod-reference`のRDS設定差分を実装する
- [ ] Secrets Managerと最小権限DBユーザー作成方式を実装する
- [ ] API Task Roleとmigration Task Roleを分離する
- [ ] ECS one-off migration taskを実装する
- [ ] Cognito User Pool、client、認証設定を実装する
- [ ] Cognito resource serverへ`tasks.read`と`tasks.write` scopeを実装する
- [ ] Authorization Code + PKCEで検証用access tokenを取得する手順を作成する
- [ ] 既存ドメインまたは委任済みサブドメインの利用方法を決定する
- [ ] Route 53 record、ACM証明書、HTTPS listenerを実装する
- [ ] HTTPからHTTPSへのredirectを実装する

### AWS検証セッションB

- [ ] 公式料金を確認し、5時間以内の概算費用を記録する
- [ ] 終了予定時刻とdestroy手順を確認する
- [ ] `dev`をapplyする
- [ ] migration taskを実行する
- [ ] Cognito JWTを使用してHTTPS経由のCRUDを確認する
- [ ] access tokenのscope不足時に操作が拒否されることを確認する
- [ ] 他利用者のtaskへアクセスできないことを確認する
- [ ] `dev`をdestroyする
- [ ] RDS snapshot、secret、DNSを含む残存リソースを確認する

## Phase 7: AWS向けCI/CD

- [ ] GitHub Actions OIDC providerを実装する
- [ ] Validate / Plan roleを最小権限で実装する
- [ ] Infrastructure Apply roleをEnvironment承認付きで実装する
- [ ] Application Deploy roleを最小権限で実装する
- [ ] ECR push workflowを実装する
- [ ] migration成功後だけECS deployするworkflowを実装する
- [ ] ECS Deployment Circuit Breakerを実装する
- [ ] デプロイ後の自動ヘルスチェックを実装する
- [ ] 失敗時の中止・rollback動作を確認する

## Phase 8: 監視・復旧・セキュリティ

- [ ] ALB、ECS、RDSのCloudWatch Alarmを実装する
- [ ] SNS通知を実装する
- [ ] Runbookを作成する
- [ ] RDS manual snapshot作成と復元手順を作成する
- [ ] RTO / RPO計測方法を決定する
- [ ] IAM、Security Group、秘密情報、公開範囲をレビューする
- [ ] 未対応リスクと将来拡張の判断を整理する

## Phase 9: 最終統合検証と公開

### AWS検証セッションC

- [ ] 公式料金を確認し、5時間以内の概算費用を記録する
- [ ] 終了予定時刻とdestroy手順を確認する
- [ ] bootstrap以外の全環境を再構築する
- [ ] GitHub Actionsからmigrationとdeployを実行する
- [ ] 認証、CRUD、データ永続化、自動health checkを確認する
- [ ] 意図的な異常でAlarmとSNS通知を確認する
- [ ] RDS snapshotから復元し、RTO / RPOを記録する
- [ ] `dev`をdestroyする
- [ ] snapshot、ECR image、log、secret、DNSを含む残存リソースを確認する
- [ ] 実際の費用を後日確認する

### 公開資料

- [ ] READMEへ最終構成、実行手順、検証結果を整理する
- [ ] 構成図を最終構成へ更新する
- [ ] セキュリティ、運用、復旧、コスト実績を整理する
- [ ] `dev`と`prod-reference`の差分を整理する
- [ ] 未対応リスクと改善候補を整理する
- [ ] 専門家レビューを反映する
- [ ] version tagとGitHub Releaseを作成する
