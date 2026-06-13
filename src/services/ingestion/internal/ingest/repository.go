package ingest

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
)

type EventWriter interface {
	Exec(context.Context, string, ...any) (pgconn.CommandTag, error)
}

type Repository struct {
	db EventWriter
}

func NewRepository(db EventWriter) *Repository {
	return &Repository{db: db}
}

func (r *Repository) InsertEvents(ctx context.Context, events []Event) error {
	for _, event := range events {
		if err := r.InsertEvent(ctx, event); err != nil {
			return err
		}
	}

	return nil
}

func (r *Repository) InsertEvent(ctx context.Context, event Event) error {
	_, err := r.db.Exec(ctx, `
INSERT INTO events (
    tenant_id,
    source,
    event_type,
    contributor_id,
    occurred_at,
    payload
) VALUES ($1, $2, $3, $4, $5, $6)
`,
		event.TenantID,
		event.Source,
		event.EventType,
		event.ContributorID,
		event.OccurredAt,
		event.Payload,
	)
	if err != nil {
		return fmt.Errorf("inserting event: %w", err)
	}

	return nil
}
