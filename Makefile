.PHONY: postgres-up postgres-down postgres-logs migrate-up api test test-integration

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

test-integration:
	go test -tags=integration ./...
