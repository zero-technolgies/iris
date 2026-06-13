package main

import "testing"

func TestLoadConfigUsesDefaults(t *testing.T) {
	cfg, err := loadConfig(func(key string) string {
		if key == "DATABASE_URL" {
			return "postgres://iris:secret@localhost:5432/iris?sslmode=disable"
		}
		return ""
	})
	if err != nil {
		t.Fatalf("loadConfig returned error: %v", err)
	}

	if cfg.DatabaseURL == "" {
		t.Fatal("expected database URL")
	}
	if cfg.MigrationsPath != defaultMigrationsPath {
		t.Fatalf("expected default migrations path %q, got %q", defaultMigrationsPath, cfg.MigrationsPath)
	}
}

func TestLoadConfigRequiresDatabaseURL(t *testing.T) {
	_, err := loadConfig(func(string) string { return "" })
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestParseDownStepsRequiresPositiveInteger(t *testing.T) {
	steps, err := parseDownSteps([]string{"down", "2"})
	if err != nil {
		t.Fatalf("parseDownSteps returned error: %v", err)
	}
	if steps != 2 {
		t.Fatalf("expected 2 steps, got %d", steps)
	}

	if _, err := parseDownSteps([]string{"down", "0"}); err == nil {
		t.Fatal("expected error for zero steps")
	}
}

func TestParseForceVersionRequiresNonNegativeInteger(t *testing.T) {
	version, err := parseForceVersion([]string{"force", "1"})
	if err != nil {
		t.Fatalf("parseForceVersion returned error: %v", err)
	}
	if version != 1 {
		t.Fatalf("expected version 1, got %d", version)
	}

	if _, err := parseForceVersion([]string{"force", "-1"}); err == nil {
		t.Fatal("expected error for negative version")
	}
}
