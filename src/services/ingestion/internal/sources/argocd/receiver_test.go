package argocd

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/zero-technolgies/iris/src/services/ingestion/internal/ingest"
)

const testSecret = "shared-webhook-secret"

func TestValidateSignatureAcceptsMatchingSecret(t *testing.T) {
	receiver := newTestReceiver(t)
	request := httptest.NewRequest(http.MethodPost, "/webhooks/argocd", nil)
	request.Header.Set(HeaderName, testSecret)

	if err := receiver.ValidateSignature(request); err != nil {
		t.Fatalf("ValidateSignature returned error: %v", err)
	}
}

func TestValidateSignatureRejectsMissingOrMismatchedSecret(t *testing.T) {
	receiver := newTestReceiver(t)

	tests := map[string]string{
		"missing":    "",
		"mismatched": "wrong-secret",
	}

	for name, headerValue := range tests {
		t.Run(name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/webhooks/argocd", nil)
			if headerValue != "" {
				request.Header.Set(HeaderName, headerValue)
			}

			err := receiver.ValidateSignature(request)
			if !errors.Is(err, ingest.ErrInvalidSignature) {
				t.Fatalf("expected ErrInvalidSignature, got %v", err)
			}
		})
	}
}

func TestParseCreatesEventFromNotificationFixtures(t *testing.T) {
	receiver := newTestReceiver(t)

	tests := map[string]struct {
		fixture    string
		eventType  string
		occurredAt time.Time
	}{
		"sync succeeded": {
			fixture:    "testdata/sync_succeeded.json",
			eventType:  "argocd.sync.succeeded",
			occurredAt: time.Date(2026, 6, 13, 5, 4, 44, 0, time.UTC),
		},
		"sync failed": {
			fixture:    "testdata/sync_failed.json",
			eventType:  "argocd.sync.failed",
			occurredAt: time.Date(2026, 6, 13, 5, 5, 44, 0, time.UTC),
		},
		"sync status unknown": {
			fixture:    "testdata/sync_status_unknown.json",
			eventType:  "argocd.sync.status_unknown",
			occurredAt: time.Date(2026, 6, 13, 5, 6, 44, 0, time.UTC),
		},
		"health degraded": {
			fixture:    "testdata/health_degraded.json",
			eventType:  "argocd.health.degraded",
			occurredAt: time.Date(2026, 6, 13, 5, 7, 44, 0, time.UTC),
		},
	}

	for name, tt := range tests {
		t.Run(name, func(t *testing.T) {
			body := readFixture(t, tt.fixture)

			events, err := receiver.Parse(body)
			if err != nil {
				t.Fatalf("Parse returned error: %v", err)
			}

			if len(events) != 1 {
				t.Fatalf("expected 1 event, got %d", len(events))
			}
			event := events[0]
			if event.Source != Source {
				t.Fatalf("expected source %q, got %q", Source, event.Source)
			}
			if event.EventType != tt.eventType {
				t.Fatalf("expected event type %q, got %q", tt.eventType, event.EventType)
			}
			if !event.OccurredAt.Equal(tt.occurredAt) {
				t.Fatalf("expected occurred_at %s, got %s", tt.occurredAt, event.OccurredAt)
			}
			if string(event.Payload) != string(body) {
				t.Fatalf("expected raw payload to match fixture")
			}
			if event.ContributorID != nil {
				t.Fatalf("expected nil contributor id, got %q", *event.ContributorID)
			}
			if event.TenantID != "" {
				t.Fatalf("expected empty tenant id before generic handler defaulting, got %q", event.TenantID)
			}
		})
	}
}

func TestParseRejectsInvalidPayload(t *testing.T) {
	receiver := newTestReceiver(t)

	tests := map[string][]byte{
		"invalid json": []byte(`{`),
		"unknown event type": []byte(`{
			"event_type": "argocd.unexpected",
			"timestamp": "2026-06-13T05:04:44Z"
		}`),
		"invalid timestamp": []byte(`{
			"event_type": "argocd.sync.succeeded",
			"timestamp": "not-a-timestamp"
		}`),
	}

	for name, body := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := receiver.Parse(body); err == nil {
				t.Fatal("expected error")
			}
		})
	}
}

func newTestReceiver(t *testing.T) *Receiver {
	t.Helper()

	receiver, err := New(testSecret)
	if err != nil {
		t.Fatalf("New returned error: %v", err)
	}

	return receiver
}

func readFixture(t *testing.T, path string) []byte {
	t.Helper()

	body, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("reading fixture: %v", err)
	}

	return body
}
