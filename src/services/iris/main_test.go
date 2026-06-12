package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlers(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		wantCode int
		wantBody string
	}{
		{
			name:     "root returns Iris v2",
			path:     "/",
			wantCode: http.StatusOK,
			wantBody: "Iris v2",
		},
		{
			name:     "healthz returns healthy JSON",
			path:     "/healthz",
			wantCode: http.StatusOK,
			wantBody: `{"status":"healthy"}`,
		},
	}

	srv := newServer(":0")

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, tt.path, nil)
			w := httptest.NewRecorder()
			srv.Handler.ServeHTTP(w, req)

			resp := w.Result()
			defer resp.Body.Close()

			if resp.StatusCode != tt.wantCode {
				t.Errorf("status = %d, want %d", resp.StatusCode, tt.wantCode)
			}

			body, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("reading body: %v", err)
			}

			if string(body) != tt.wantBody {
				t.Errorf("body = %q, want %q", string(body), tt.wantBody)
			}
		})
	}
}
