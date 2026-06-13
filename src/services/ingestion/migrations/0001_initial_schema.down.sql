DROP INDEX IF EXISTS contributors_external_refs_gin_idx;
DROP INDEX IF EXISTS contributors_tenant_type_idx;
DROP INDEX IF EXISTS events_tenant_event_type_occurred_at_idx;
DROP INDEX IF EXISTS events_tenant_contributor_idx;
DROP INDEX IF EXISTS events_tenant_source_occurred_at_idx;

DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS contributors;
DROP TABLE IF EXISTS tenants;

DROP TYPE IF EXISTS event_source;
DROP TYPE IF EXISTS contributor_type;

DROP EXTENSION IF EXISTS pgcrypto;
