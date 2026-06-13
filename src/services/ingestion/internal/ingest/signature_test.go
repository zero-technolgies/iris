package ingest

import "testing"

func TestSecureCompare(t *testing.T) {
	if !SecureCompare([]byte("expected"), []byte("expected")) {
		t.Fatal("expected equal signatures to match")
	}

	if SecureCompare([]byte("expected"), []byte("different")) {
		t.Fatal("expected different signatures not to match")
	}
}
