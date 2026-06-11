.PHONY: postgres-up postgres-down postgres-logs

postgres-up:
	docker compose up -d postgres

postgres-down:
	docker compose down

postgres-logs:
	docker compose logs -f postgres

