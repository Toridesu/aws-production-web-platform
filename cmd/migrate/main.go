package main

import (
	"errors"
	"flag"
	"log/slog"
	"os"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

func main() {
	sourceURL := flag.String("source", "file://migrations", "migration source URL")
	flag.Parse()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://platform_app:local-development-only@localhost:5432/platform?sslmode=disable"
	}

	migration, err := migrate.New(*sourceURL, databaseURL)
	if err != nil {
		slog.Error("migration initialization failed", "error", err)
		os.Exit(1)
	}
	defer migration.Close()

	if err := migration.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		slog.Error("migration failed", "error", err)
		os.Exit(1)
	}
	slog.Info("migration completed")
}
