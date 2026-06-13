package config

import (
	"log/slog"
	"testing"
)

func TestLoadUsesDefaults(t *testing.T) {
	cfg, err := Load(func(key string) string {
		switch key {
		case "DATABASE_URL":
			return "postgres://iris:secret@localhost:5432/iris?sslmode=disable"
		case "ARGOCD_WEBHOOK_SECRET":
			return "shared-secret"
		default:
			return ""
		}
	})
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.Port != defaultPort {
		t.Fatalf("expected default port %q, got %q", defaultPort, cfg.Port)
	}
	if cfg.LogLevel != slog.LevelInfo {
		t.Fatalf("expected info log level, got %s", cfg.LogLevel)
	}
	if cfg.Environment != "dev" {
		t.Fatalf("expected dev environment, got %q", cfg.Environment)
	}
	if cfg.ArgoCDWebhookSecret != "shared-secret" {
		t.Fatalf("expected argocd webhook secret to load")
	}
}

func TestLoadRequiresDatabaseURL(t *testing.T) {
	_, err := Load(func(string) string { return "" })
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestLoadRequiresArgoCDWebhookSecret(t *testing.T) {
	_, err := Load(func(key string) string {
		if key == "DATABASE_URL" {
			return "postgres://iris:secret@localhost:5432/iris?sslmode=disable"
		}
		return ""
	})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestLoadParsesLogLevel(t *testing.T) {
	cfg, err := Load(func(key string) string {
		switch key {
		case "DATABASE_URL":
			return "postgres://iris:secret@localhost:5432/iris?sslmode=disable"
		case "ARGOCD_WEBHOOK_SECRET":
			return "shared-secret"
		case "LOG_LEVEL":
			return "debug"
		default:
			return ""
		}
	})
	if err != nil {
		t.Fatalf("Load returned error: %v", err)
	}

	if cfg.LogLevel != slog.LevelDebug {
		t.Fatalf("expected debug log level, got %s", cfg.LogLevel)
	}
}
