package main

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/zero-technolgies/iris/src/services/ingestion/internal/config"
	"github.com/zero-technolgies/iris/src/services/ingestion/internal/ingest"
	"github.com/zero-technolgies/iris/src/services/ingestion/internal/logging"
	"github.com/zero-technolgies/iris/src/services/ingestion/internal/postgres"
	"github.com/zero-technolgies/iris/src/services/ingestion/internal/server"
	"github.com/zero-technolgies/iris/src/services/ingestion/internal/sources/argocd"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "ingestion exited: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}

	logger := logging.New(cfg.Environment, cfg.LogLevel, os.Stdout)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := postgres.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		return err
	}
	defer pool.Close()

	receivers, err := webhookReceivers(cfg)
	if err != nil {
		return err
	}

	httpServer := server.New(cfg.Address(), pool, receivers, logger)

	serverErr := make(chan error, 1)
	go func() {
		logger.Info("ingestion starting", "addr", httpServer.Addr)
		serverErr <- httpServer.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		logger.Info("shutdown signal received")
	case err := <-serverErr:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("running server: %w", err)
		}
		return nil
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := httpServer.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("shutting down server: %w", err)
	}

	return nil
}

func webhookReceivers(cfg config.Config) (map[string]ingest.Receiver, error) {
	argocdReceiver, err := argocd.New(cfg.ArgoCDWebhookSecret)
	if err != nil {
		return nil, fmt.Errorf("creating argocd receiver: %w", err)
	}

	return map[string]ingest.Receiver{
		"/webhooks/argocd": argocdReceiver,
	}, nil
}
