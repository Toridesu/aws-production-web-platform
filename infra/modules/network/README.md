# Network module

このmoduleは、`dev`と`prod-reference`で再利用するVPC基盤を作成します。

作成するもの:

- DNS supportを有効にしたVPC
- ALBとNAT Gateway用のPublic subnet 2つ
- ECS task用のPrivate Application subnet 2つ
- 将来のRDS用Private Database subnet 2つ
- Internet Gateway
- `nat_gateway_count`で台数を制御するNAT Gateway 1台または2台
- subnet tierごとに分離したroute table
- Private subnet用route tableに関連付けるS3 Gateway VPC endpoint

呼び出し側は、2つのAvailability ZoneとCIDRを同じ順番で明示的に渡します。このmoduleはALB、ECS、RDS、Security Group、IAM resourceを作成しません。

`dev`では費用を抑えるため`nat_gateway_count = 1`にします。`prod-reference`ではAvailability Zone障害時の外向き通信依存を分離するため、`nat_gateway_count = 2`にします。
