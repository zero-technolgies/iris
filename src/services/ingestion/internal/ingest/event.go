package ingest

import (
	"encoding/json"
	"time"
)

const IrisTenantID = "00000000-0000-0000-0000-000000000001"

type Event struct {
	ID            string
	TenantID      string
	Source        string
	EventType     string
	ContributorID *string
	OccurredAt    time.Time
	IngestedAt    time.Time
	Payload       json.RawMessage
}
