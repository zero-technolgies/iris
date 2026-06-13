package server

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/jackc/pgx/v5/pgconn"
)

type fakePinger struct {
	err error
}

func (p fakePinger) Ping(context.Context) error {
	return p.err
}

func (p fakePinger) Exec(context.Context, string, ...any) (pgconn.CommandTag, error) {
	return pgconn.NewCommandTag("INSERT 0 1"), nil
}

func TestHealthzReturnsOKWhenPostgresIsReachable(t *testing.T) {
	handler := NewHandler(fakePinger{}, nil, testLogger())
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected %d, got %d", http.StatusOK, response.Code)
	}
	if response.Body.String() != "{\"status\":\"healthy\"}\n" {
		t.Fatalf("unexpected body %q", response.Body.String())
	}
}

func TestHealthzReturnsUnavailableWhenPostgresPingFails(t *testing.T) {
	handler := NewHandler(fakePinger{err: errors.New("database unavailable")}, nil, testLogger())
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("expected %d, got %d", http.StatusServiceUnavailable, response.Code)
	}
	if response.Body.String() != "{\"status\":\"unhealthy\"}\n" {
		t.Fatalf("unexpected body %q", response.Body.String())
	}
}

func TestReadyzReturnsOK(t *testing.T) {
	handler := NewHandler(fakePinger{}, nil, testLogger())
	request := httptest.NewRequest(http.MethodGet, "/readyz", nil)
	response := httptest.NewRecorder()

	handler.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("expected %d, got %d", http.StatusOK, response.Code)
	}
	if response.Body.String() != "{\"status\":\"ready\"}\n" {
		t.Fatalf("unexpected body %q", response.Body.String())
	}
}

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
