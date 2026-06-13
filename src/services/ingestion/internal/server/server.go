package server

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"
)

type Pinger interface {
	Ping(context.Context) error
}

type Handler struct {
	db     Pinger
	logger *slog.Logger
}

func New(addr string, db Pinger, logger *slog.Logger) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           NewHandler(db, logger),
		ReadHeaderTimeout: 5 * time.Second,
	}
}

func NewHandler(db Pinger, logger *slog.Logger) http.Handler {
	handler := &Handler{
		db:     db,
		logger: logger,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", handler.healthz)
	mux.HandleFunc("GET /readyz", handler.readyz)

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
