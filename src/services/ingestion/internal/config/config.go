package config

import (
	"fmt"
	"log/slog"
	"strings"
)

const defaultPort = "8080"

type Config struct {
	Port                string
	DatabaseURL         string
	ArgoCDWebhookSecret string
	LogLevel            slog.Level
	Environment         string
}

func Load(getenv func(string) string) (Config, error) {
	port := getenv("PORT")
	if port == "" {
		port = defaultPort
	}

	databaseURL := getenv("DATABASE_URL")
	if databaseURL == "" {
		return Config{}, fmt.Errorf("DATABASE_URL is required")
	}

	argocdWebhookSecret := getenv("ARGOCD_WEBHOOK_SECRET")
	if argocdWebhookSecret == "" {
		return Config{}, fmt.Errorf("ARGOCD_WEBHOOK_SECRET is required")
	}

	logLevel, err := parseLogLevel(getenv("LOG_LEVEL"))
	if err != nil {
		return Config{}, err
	}

	environment := getenv("ENV")
	if environment == "" {
		environment = "dev"
	}

	return Config{
		Port:                port,
		DatabaseURL:         databaseURL,
		ArgoCDWebhookSecret: argocdWebhookSecret,
		LogLevel:            logLevel,
		Environment:         strings.ToLower(environment),
	}, nil
}

func (c Config) Address() string {
	return ":" + c.Port
}

func parseLogLevel(value string) (slog.Level, error) {
	switch strings.ToLower(value) {
	case "", "info":
		return slog.LevelInfo, nil
	case "debug":
		return slog.LevelDebug, nil
	case "warn", "warning":
		return slog.LevelWarn, nil
	case "error":
		return slog.LevelError, nil
	default:
		return slog.LevelInfo, fmt.Errorf("invalid LOG_LEVEL %q", value)
	}
}
