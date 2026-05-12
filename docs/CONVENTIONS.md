# Iris — Conventions

## Commits
- [Conventional Commits](https://www.conventionalcommits.org/) format
- `type(scope): summary`
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `build`, `ci`
- Scope is the service or area: `feat(ingestion): add github webhook handler`
- Body explains the why, not the what
- Reference ClickUp at the end when relevant: `Refs: CU-86b9u2c4g`

## Branches
- `main` is always deployable
- Feature: `feat/<short-description>`
- Fix: `fix/<short-description>`
- Doc: `docs/<short-description>`
- One PR per branch. Short-lived (days, not weeks).

## Pull Requests
- Every PR uses the PR template
- Title format matches commit format
- Description includes the linked ClickUp task and acceptance criteria pasted verbatim
- One AI owns a branch from start to merge — no mid-stream handoffs
- The reviewer checks each acceptance criterion explicitly

## Code style — Go
- `gofmt` and `goimports` on save
- `golangci-lint` clean
- Errors wrapped with context: `fmt.Errorf("loading config: %w", err)`
- No `panic` in service code
- `context.Context` is the first parameter of any I/O function
- Logger is structured (`slog`), passed through context or as parameter — never global

## Testing
- Every service has a `_test.go` next to the code
- Unit tests are the default; integration tests gated by a build tag
- Tests read like specifications, not coverage padding
- PRs adding features without tests must explain why in the PR body

## Error handling
- Errors flow up; recovery happens at the top of the call stack
- HTTP handlers return structured errors with appropriate status codes
- Database errors get wrapped with the triggering operation
- Log at the boundary (service entry/exit), not at every call

## Secrets
- Never committed, ever
- Never logged
- v0: Kubernetes Secrets, manually created
- v1+: external-secrets-operator with a vault provider
- `.env` files for local dev only, in `.gitignore`

## Configuration
- All config via environment variables
- A service must run with sane defaults for local dev
- Production config overlaid via ConfigMaps and Secrets

## Database migrations
- One migration file per change, numbered sequentially
- Forward-only; rollback is a new forward migration
- Tooling: TBD via ADR

## Logging and observability
- Structured logs (JSON in prod, human-readable in dev)
- Every handled event logs: event type, contributor ID, tenant ID, outcome
- Metrics via OpenTelemetry; scraped by Mimir
- Trace IDs propagated across service boundaries
