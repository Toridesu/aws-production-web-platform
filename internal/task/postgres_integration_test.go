//go:build integration

package task

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

func TestPostgresRepositoryCRUDAndOwnerIsolation(t *testing.T) {
	databaseURL := os.Getenv("TEST_DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://platform_app:local-development-only@localhost:5432/platform?sslmode=disable"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("pgxpool.New: %v", err)
	}
	defer pool.Close()
	if _, err := pool.Exec(ctx, "TRUNCATE tasks"); err != nil {
		t.Fatalf("TRUNCATE tasks: %v", err)
	}

	repository := NewPostgresRepository(pool)
	created, err := repository.Create(ctx, "user-a", CreateInput{Title: "learn Go", Description: "write API"})
	if err != nil {
		t.Fatalf("Create: %v", err)
	}

	if _, err := repository.Get(ctx, "user-b", created.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("other owner Get error = %v, want ErrNotFound", err)
	}

	status := StatusDone
	updated, err := repository.Update(ctx, "user-a", created.ID, UpdateInput{Status: &status})
	if err != nil {
		t.Fatalf("Update: %v", err)
	}
	if updated.Status != StatusDone {
		t.Fatalf("status = %q, want %q", updated.Status, StatusDone)
	}

	items, err := repository.List(ctx, "user-a")
	if err != nil {
		t.Fatalf("List: %v", err)
	}
	if len(items) != 1 || items[0].ID != created.ID {
		t.Fatalf("unexpected items: %#v", items)
	}

	if err := repository.Delete(ctx, "user-b", created.ID); !errors.Is(err, ErrNotFound) {
		t.Fatalf("other owner Delete error = %v, want ErrNotFound", err)
	}
	if err := repository.Delete(ctx, "user-a", created.ID); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if _, err := repository.Get(ctx, "user-a", uuid.New()); !errors.Is(err, ErrNotFound) {
		t.Fatalf("unknown task Get error = %v, want ErrNotFound", err)
	}
}
