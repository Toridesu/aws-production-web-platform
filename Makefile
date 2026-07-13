.PHONY: postgres-up postgres-down postgres-logs migrate-up api test test-race test-integration vet vuln docker-build

postgres-up:
	docker compose up -d postgres

postgres-down:
	docker compose down

postgres-logs:
	docker compose logs -f postgres

migrate-up:
	go run ./cmd/migrate

api:
	go run ./cmd/api

test:
	go test ./...

test-race:
	go test -race -count=1 ./...

test-integration:
	go test -race -count=1 -tags=integration ./...

vet:
	go vet ./...

vuln:
	go run golang.org/x/vuln/cmd/govulncheck@v1.5.0 ./...

docker-build:
	docker build --pull --tag aws-production-web-platform-api:local .
