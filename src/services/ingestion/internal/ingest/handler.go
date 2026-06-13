package ingest

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
)

type Store interface {
	InsertEvents(context.Context, []Event) error
}

type Handler struct {
	receivers map[string]Receiver
	store     Store
	logger    *slog.Logger
}

func NewHandler(receivers map[string]Receiver, store Store, logger *slog.Logger) *Handler {
	copied := make(map[string]Receiver, len(receivers))
	for path, receiver := range receivers {
		copied[path] = receiver
	}

	return &Handler{
		receivers: copied,
		store:     store,
		logger:    logger,
	}
}

func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /webhooks/{source}", h.handleWebhook)
}

func (h *Handler) handleWebhook(w http.ResponseWriter, r *http.Request) {
	receiver, ok := h.receivers[r.URL.Path]
	if !ok {
		h.writeJSON(w, http.StatusNotFound, map[string]string{"error": "unknown webhook"})
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		h.logger.Warn("failed to read webhook body", "path", r.URL.Path, "err", err)
		h.writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid request body"})
		return
	}
	r.Body = io.NopCloser(bytes.NewReader(body))

	if err := receiver.ValidateSignature(r); err != nil {
		if errors.Is(err, ErrInvalidSignature) {
			h.logger.Warn("webhook signature validation failed", "path", r.URL.Path)
			h.writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid signature"})
			return
		}

		h.logger.Warn("webhook signature validation error", "path", r.URL.Path, "err", err)
		h.writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid signature"})
		return
	}

	events, err := receiver.Parse(body)
	if err != nil {
		h.logger.Warn("webhook parse failed", "path", r.URL.Path, "err", err)
		h.writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid webhook payload"})
		return
	}

	for i := range events {
		if events[i].TenantID == "" {
			events[i].TenantID = IrisTenantID
		}
	}

	if err := h.store.InsertEvents(r.Context(), events); err != nil {
		h.logger.Error("webhook event persistence failed", "path", r.URL.Path, "err", err)
		h.writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to persist events"})
		return
	}

	h.writeJSON(w, http.StatusAccepted, map[string]int{"events": len(events)})
}

func (h *Handler) writeJSON(w http.ResponseWriter, statusCode int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	if err := json.NewEncoder(w).Encode(body); err != nil {
		h.logger.Warn("failed to write response", "err", err)
	}
}
