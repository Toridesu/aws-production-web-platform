# internal

外部パッケージとして公開しないアプリケーションコードを配置します。

予定する責務:

- `auth`: Cognito JWT検証
- `config`: 環境設定
- `httpapi`: HTTP handlerとmiddleware
- `task`: taskのserviceとrepository
- `platform`: database、loggingなどの共通基盤

実装はPhase 2で追加します。

