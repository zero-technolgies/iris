package argocd

import (
	"crypto/subtle"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/zero-technolgies/iris/src/services/ingestion/internal/ingest"
)

const (
	HeaderName = "X-Iris-Webhook-Secret"
	Source     = "argocd"
)

var knownEventTypes = map[string]struct{}{
	"argocd.sync.succeeded":      {},
	"argocd.sync.failed":         {},
	"argocd.sync.status_unknown": {},
	"argocd.health.degraded":     {},
}

type Receiver struct {
	secret string
}

func New(secret string) (*Receiver, error) {
	if secret == "" {
		return nil, fmt.Errorf("argocd webhook secret is required")
	}

	return &Receiver{secret: secret}, nil
}

func (r *Receiver) ValidateSignature(req *http.Request) error {
	presentedSecret := req.Header.Get(HeaderName)
	if presentedSecret == "" {
		return ingest.ErrInvalidSignature
	}

	if subtle.ConstantTimeCompare([]byte(presentedSecret), []byte(r.secret)) != 1 {
		return ingest.ErrInvalidSignature
	}

	return nil
}

func (r *Receiver) Parse(body []byte) ([]ingest.Event, error) {
	var payload struct {
		EventType string `json:"event_type"`
		Timestamp string `json:"timestamp"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("unmarshalling argocd payload: %w", err)
	}

	if _, ok := knownEventTypes[payload.EventType]; !ok {
		return nil, fmt.Errorf("unsupported argocd event_type %q", payload.EventType)
	}

	occurredAt, err := time.Parse(time.RFC3339, payload.Timestamp)
	if err != nil {
		return nil, fmt.Errorf("parsing argocd timestamp: %w", err)
	}

	rawPayload := append(json.RawMessage(nil), body...)

	return []ingest.Event{{
		Source:     Source,
		EventType:  payload.EventType,
		OccurredAt: occurredAt,
		Payload:    rawPayload,
	}}, nil
}
