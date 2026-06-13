package logging

import (
	"io"
	"log/slog"
)

func New(environment string, level slog.Level, out io.Writer) *slog.Logger {
	options := &slog.HandlerOptions{Level: level}
	if environment == "prod" || environment == "production" {
		return slog.New(slog.NewJSONHandler(out, options))
	}

	return slog.New(slog.NewTextHandler(out, options))
}
