package server

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/zero-technolgies/iris/src/services/ingestion/internal/ingest"
)

type Pinger interface {
	Ping(context.Context) error
}

type Database interface {
	Pinger
	ingest.EventWriter
}

type Handler struct {
	db     Pinger
	logger *slog.Logger
}

func New(addr string, db Database, webhookReceivers map[string]ingest.Receiver, logger *slog.Logger) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           NewHandler(db, webhookReceivers, logger),
		ReadHeaderTimeout: 5 * time.Second,
	}
}

func NewHandler(db Database, webhookReceivers map[string]ingest.Receiver, logger *slog.Logger) http.Handler {
	handler := &Handler{
		db:     db,
		logger: logger,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handler.healthz)
	mux.HandleFunc("GET /readyz", handler.readyz)
	ingest.NewHandler(webhookReceivers, ingest.NewRepository(db), logger).Register(mux)

	return mux
}

func (h *Handler) healthz(w http.ResponseWriter, r *http.Request) {
	if err := h.db.Ping(r.Context()); err != nil {
		h.logger.Warn("health check failed", "err", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "unhealthy"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "healthy"})
}

func (h *Handler) readyz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func writeJSON(w http.ResponseWriter, statusCode int, body map[string]string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(body)
}
