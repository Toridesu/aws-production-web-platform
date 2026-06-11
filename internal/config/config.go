package config

import (
	"fmt"
	"os"
	"time"
)

type Config struct {
	Address         string
	DatabaseURL     string
	AuthMode        string
	LogLevel        string
	ShutdownTimeout time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		Address:         getenv("APP_ADDRESS", ":8080"),
		DatabaseURL:     getenv("DATABASE_URL", "postgres://platform_app:local-development-only@localhost:5432/platform?sslmode=disable"),
		AuthMode:        getenv("AUTH_MODE", "dev"),
		LogLevel:        getenv("LOG_LEVEL", "info"),
		ShutdownTimeout: 10 * time.Second,
	}

	if cfg.AuthMode != "dev" {
		return Config{}, fmt.Errorf("AUTH_MODE %q is not supported yet; use dev for local development", cfg.AuthMode)
	}

	return cfg, nil
}

func getenv(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
