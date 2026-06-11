package config

import "testing"

func TestLoadDefaults(t *testing.T) {
	clearConfigEnvironment(t)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}
	if cfg.Address != ":8080" || cfg.AuthMode != "dev" || cfg.DatabaseURL == "" {
		t.Fatalf("unexpected defaults: %#v", cfg)
	}
}

func TestLoadRejectsUnsupportedAuthMode(t *testing.T) {
	clearConfigEnvironment(t)
	t.Setenv("AUTH_MODE", "cognito")

	if _, err := Load(); err == nil {
		t.Fatal("Load returned nil error for unsupported auth mode")
	}
}

func clearConfigEnvironment(t *testing.T) {
	t.Helper()
	for _, key := range []string{"APP_ADDRESS", "DATABASE_URL", "AUTH_MODE", "LOG_LEVEL"} {
		t.Setenv(key, "")
	}
}
