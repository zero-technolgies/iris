//go:build integration

package ingest

import (
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func TestWebhookHandlerPersistsEventsToPostgres(t *testing.T) {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		t.Skip("DATABASE_URL is required for integration tests")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("creating database pool: %v", err)
	}
	defer pool.Close()

	if _, err := pool.Exec(ctx, "DELETE FROM events WHERE event_type = 'fake.integration'"); err != nil {
		t.Fatalf("cleaning events: %v", err)
	}

	occurredAt := time.Date(2026, 6, 13, 1, 2, 3, 0, time.UTC)
	receiver := &fakeReceiver{events: []Event{{
		Source:     "github",
		EventType:  "fake.integration",
		OccurredAt: occurredAt,
		Payload:    json.RawMessage(`{"kind":"fake"}`),
	}}}

	mux := http.NewServeMux()
	NewHandler(
		map[string]Receiver{"/webhooks/github": receiver},
		NewRepository(pool),
		slog.New(slog.NewTextHandler(io.Discard, nil)),
	).Register(mux)

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{"kind":"fake"}`))
	response := httptest.NewRecorder()

	mux.ServeHTTP(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("expected %d, got %d", http.StatusAccepted, response.Code)
	}

	var count int
	err = pool.QueryRow(ctx, `
SELECT count(*)
FROM events
WHERE tenant_id = $1
  AND source = 'github'
  AND event_type = 'fake.integration'
  AND occurred_at = $2
  AND payload = '{"kind":"fake"}'::jsonb
`, IrisTenantID, occurredAt).Scan(&count)
	if err != nil {
		t.Fatalf("querying persisted events: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected 1 persisted row, got %d", count)
	}
}
