# AWS Production Web Platform

> 状態: Phase 3完了 / Go APIのcontainer化、CI、GitHub上の実行確認完了

Goで実装したタスク管理APIを題材に、データベース、認証、HTTPS、CI/CD、監視、バックアップ、復旧まで含めた本番想定AWS基盤を設計・構築するポートフォリオです。

短時間だけ実際に構築する`dev`環境と、本番要件を表現する`prod-reference`環境を分離します。`prod-reference`は原則として`terraform plan`までとし、費用を抑えながら本番設計との差分を説明できる構成にします。

## 証明する技術

- Go APIとPostgreSQLの設計・実装・テスト
- Terraformによる再現可能なAWS基盤とリモートステート運用
- パブリック、アプリケーション、データベース層の通信制御
- Cognito JWT認証、Secrets Manager、最小権限IAM
- GitHub Actions OIDCによる安全なCI/CD
- データベースマイグレーションと安全なローリングデプロイ
- CloudWatch、SNS、バックアップ、復旧試験
- コスト上限を設定した短時間検証と確実な後片付け

## 確定した主要構成

- Go REST API / PostgreSQL
- Amazon Cognito User Pool
- Application Load Balancer / ACM / Route 53
- Amazon ECS on AWS Fargate / Amazon ECR
- Amazon RDS for PostgreSQL / AWS Secrets Manager
- Amazon CloudWatch / Amazon SNS
- GitHub Actions OIDC
- Terraform S3 backend / S3 lockfile

## 構成図

![AWS Production Web Platform構成図](assets/architecture/aws-production-web-platform-architecture.png)

## 環境方針

| 項目 | `dev` | `prod-reference` |
| --- | --- | --- |
| 用途 | 短時間の実動作検証 | 本番想定設計の確認 |
| 実際の構築 | 承認後に実施 | 原則`plan`のみ |
| ECS | 1タスク | 2タスク以上 |
| NAT Gateway | 1台 | AZごと |
| RDS | Single-AZ | Multi-AZ |
| 削除保護 | 無効 | 有効 |
| 検証後 | 同日中にdestroy | 構築しない |

## ローカル開発

### 前提ツール

- Go `1.26.5`
- Docker Desktop `28.x`
- Terraform `>= 1.15.0, < 1.16.0`
- Git

### PostgreSQLを起動する

```bash
cp .env.example .env
docker compose up -d postgres
docker compose ps
```

停止する場合:

```bash
docker compose down
```

データも削除する場合:

```bash
docker compose down -v
```

`.env`はローカル専用で、Git管理されません。`.env.example`の値は開発用であり、AWS環境では使用しません。

### MigrationとAPIを起動する

```bash
go run ./cmd/migrate
go run ./cmd/api
```

別のターミナルからhealth checkを確認します。

```bash
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

ローカル開発ではBearer tokenの文字列を利用者IDとして扱います。

```bash
curl -X POST http://localhost:8080/api/v1/tasks \
  -H "Authorization: Bearer local-user-a" \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Go API","description":"Create first task"}'

curl http://localhost:8080/api/v1/tasks \
  -H "Authorization: Bearer local-user-a"
```

この開発用認証はローカル専用です。AWS環境ではCognito access token検証へ置き換えます。

### Docker containerで起動する

APIとmigrationは同じimageから実行します。`go run ./cmd/api`を実行中の場合は、ポート競合を避けるため先に`Ctrl+C`で停止します。

```bash
docker compose build api
docker compose run --rm migrate
docker compose up -d api
docker compose ps api
```

`api`が`healthy`になった後、次を確認します。

```bash
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

API containerだけを停止・削除する場合:

```bash
docker compose stop --timeout 10 api
docker compose rm -f api
```

Dockerfileはmulti-stage buildを使用し、実行用imageへGo compilerを含めません。APIは非rootユーザーで動作し、Composeではread-only filesystem、全Linux capability削除、権限昇格禁止を設定しています。

### テスト

```bash
go test ./...
go test -race -count=1 ./...
go test -race -count=1 -tags=integration ./...
go vet ./...
go run golang.org/x/vuln/cmd/govulncheck@v1.5.0 ./...
```

Integration Testの前にPostgreSQLを起動し、migrationを適用してください。テストはローカルDBの`tasks` tableを空にするため、学習用データが必要な場合は専用DBを使用します。

## CI

GitHub Actionsは`main`へのpush、`main`向けPull Request、手動実行で起動します。

| Check | 確認内容 |
| --- | --- |
| `Go Quality` | race detector付きUnit Test、`go vet`、`govulncheck` |
| `PostgreSQL Integration` | 一時PostgreSQL、migration、race detector付きIntegration Test |
| `Container Security` | Docker build、CycloneDX SBOM、High/Critical脆弱性検査 |

workflow全体の権限は`contents: read`だけに制限し、外部Actionは完全なcommit SHAへ固定しています。同じbranchの古い実行は`concurrency`で中止されます。SBOMはGitHub Actionsのartifactとして14日間保存します。

`main`のbranch protectionまたはrulesetでは、Pull Requestを必須にし、上記3つのCheckをrequired status checksへ指定します。管理者による回避を許可するかは、個人開発中の作業性と完成後の保護方針を分けて判断します。

## ディレクトリ構成

```text
Dockerfile    APIとmigrationのmulti-stage container image
cmd/api/      HTTP APIのエントリーポイント
cmd/migrate/  Migration専用エントリーポイント
internal/     認証、HTTP、task、設定
migrations/   PostgreSQL schema migration SQL
infra/        Terraform
private_docs/ Codex向け計画・TODO・学習資料（Git管理対象外）
```

## 現在の状態

- 計画と主要設計判断は`private_docs`へ整理済みです
- GitとローカルPostgreSQL開発基盤は準備済みです
- Go API、task CRUD、local migrationは実装済みです
- 非root・multi-stage Docker imageとローカルcontainer検証は完了しています
- Go、PostgreSQL、Docker imageを検査するGitHub Actions CIは実装済みです
- Cognito認証とTerraformは未実装です
- AWSリソースは作成していません
- GitHub上でCIの3つのCheckとSBOM生成を確認済みです
- 次の実装作業はTerraform bootstrapと環境構成です
