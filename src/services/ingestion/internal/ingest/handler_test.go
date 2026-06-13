package ingest

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type fakeReceiver struct {
	validateErr error
	validate    func(*http.Request) error
	events      []Event
	parseErr    error
	body        []byte
}

func (r *fakeReceiver) ValidateSignature(req *http.Request) error {
	if r.validate != nil {
		return r.validate(req)
	}
	return r.validateErr
}

func (r *fakeReceiver) Parse(body []byte) ([]Event, error) {
	r.body = body
	return r.events, r.parseErr
}

type fakeStore struct {
	events []Event
	err    error
}

func (s *fakeStore) InsertEvents(_ context.Context, events []Event) error {
	s.events = append(s.events, events...)
	return s.err
}

func TestHandlerPersistsParsedEvents(t *testing.T) {
	occurredAt := time.Date(2026, 6, 13, 0, 0, 0, 0, time.UTC)
	receiver := &fakeReceiver{
		events: []Event{{
			Source:     "github",
			EventType:  "push",
			OccurredAt: occurredAt,
			Payload:    json.RawMessage(`{"ref":"main"}`),
		}},
	}
	store := &fakeStore{}
	handler := testHandler(map[string]Receiver{"/webhooks/github": receiver}, store)

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{"ok":true}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("expected %d, got %d", http.StatusAccepted, response.Code)
	}
	if len(store.events) != 1 {
		t.Fatalf("expected 1 persisted event, got %d", len(store.events))
	}
	if store.events[0].TenantID != IrisTenantID {
		t.Fatalf("expected default tenant %q, got %q", IrisTenantID, store.events[0].TenantID)
	}
	if string(receiver.body) != `{"ok":true}` {
		t.Fatalf("expected body to be passed to receiver, got %q", string(receiver.body))
	}
}

func TestHandlerReturnsUnauthorizedForInvalidSignature(t *testing.T) {
	handler := testHandler(map[string]Receiver{
		"/webhooks/github": &fakeReceiver{validateErr: ErrInvalidSignature},
	}, &fakeStore{})

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected %d, got %d", http.StatusUnauthorized, response.Code)
	}
}

func TestHandlerRestoresBodyBeforeSignatureValidation(t *testing.T) {
	receiver := &fakeReceiver{
		validate: func(req *http.Request) error {
			body, err := io.ReadAll(req.Body)
			if err != nil {
				t.Fatalf("reading request body: %v", err)
			}
			if string(body) != `{"ok":true}` {
				t.Fatalf("expected signature validator to read body, got %q", string(body))
			}
			return nil
		},
		events: []Event{{
			Source:     "github",
			EventType:  "push",
			OccurredAt: time.Now(),
			Payload:    json.RawMessage(`{}`),
		}},
	}
	handler := testHandler(map[string]Receiver{"/webhooks/github": receiver}, &fakeStore{})

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{"ok":true}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusAccepted {
		t.Fatalf("expected %d, got %d", http.StatusAccepted, response.Code)
	}
	if string(receiver.body) != `{"ok":true}` {
		t.Fatalf("expected parser to receive body, got %q", string(receiver.body))
	}
}

func TestHandlerReturnsBadRequestForParseError(t *testing.T) {
	handler := testHandler(map[string]Receiver{
		"/webhooks/github": &fakeReceiver{parseErr: errors.New("bad payload")},
	}, &fakeStore{})

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("expected %d, got %d", http.StatusBadRequest, response.Code)
	}
}

func TestHandlerReturnsNotFoundForUnknownWebhook(t *testing.T) {
	handler := testHandler(nil, &fakeStore{})

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusNotFound {
		t.Fatalf("expected %d, got %d", http.StatusNotFound, response.Code)
	}
}

func TestHandlerReturnsServerErrorWhenPersistenceFails(t *testing.T) {
	handler := testHandler(map[string]Receiver{
		"/webhooks/github": &fakeReceiver{events: []Event{{
			Source:     "github",
			EventType:  "push",
			OccurredAt: time.Now(),
			Payload:    json.RawMessage(`{}`),
		}}},
	}, &fakeStore{err: errors.New("insert failed")})

	request := httptest.NewRequest(http.MethodPost, "/webhooks/github", stringsReader(`{}`))
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusInternalServerError {
		t.Fatalf("expected %d, got %d", http.StatusInternalServerError, response.Code)
	}
}

func testHandler(receivers map[string]Receiver, store Store) http.Handler {
	mux := http.NewServeMux()
	NewHandler(receivers, store, slog.New(slog.NewTextHandler(io.Discard, nil))).Register(mux)
	return mux
}

func stringsReader(value string) io.Reader {
	return strings.NewReader(value)
}
