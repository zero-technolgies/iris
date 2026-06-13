CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE contributor_type AS ENUM (
    'human',
    'coding_agent',
    'voice_agent',
    'review_agent',
    'unknown'
);

CREATE TYPE event_source AS ENUM (
    'github',
    'github_actions',
    'argocd',
    'kubernetes',
    'grafana'
);

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE contributors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    type contributor_type NOT NULL DEFAULT 'unknown',
    display_name TEXT NOT NULL,
    external_refs JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, id),
    CONSTRAINT contributors_display_name_not_empty CHECK (btrim(display_name) <> ''),
    CONSTRAINT contributors_external_refs_object CHECK (jsonb_typeof(external_refs) = 'object')
);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    source event_source NOT NULL,
    event_type TEXT NOT NULL,
    contributor_id UUID,
    occurred_at TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT events_contributor_tenant_fk
        FOREIGN KEY (tenant_id, contributor_id)
        REFERENCES contributors(tenant_id, id)
        ON DELETE SET NULL (contributor_id),
    CONSTRAINT events_event_type_not_empty CHECK (btrim(event_type) <> ''),
    CONSTRAINT events_payload_object CHECK (jsonb_typeof(payload) = 'object')
);

CREATE INDEX events_tenant_source_occurred_at_idx
    ON events (tenant_id, source, occurred_at DESC);

CREATE INDEX events_tenant_contributor_idx
    ON events (tenant_id, contributor_id);

CREATE INDEX events_tenant_event_type_occurred_at_idx
    ON events (tenant_id, event_type, occurred_at DESC);

CREATE INDEX contributors_tenant_type_idx
    ON contributors (tenant_id, type);

CREATE INDEX contributors_external_refs_gin_idx
    ON contributors USING GIN (external_refs);
