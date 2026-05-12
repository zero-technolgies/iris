# Iris — AI Collaboration Model

## Why this document exists
Iris is built by one human and three AI systems. This is the working model that prevents drift, redundant work, and conflicting decisions. Read this before starting any session.

## Roles

### Caleb (human)
- Final authority on direction and merge decisions
- Resolves disagreements between AIs
- Owns the ClickUp board
- Reviews and merges all PRs

### Claude (chat — claude.ai)
- Strategy and architecture decisions
- ClickUp planning (creates folders, lists, stories, subtasks)
- Authors documentation, ADRs, design docs
- Does NOT touch the repo directly. Output is text/markdown Caleb commits.

### Claude Code (in VS Code)
- Implements ClickUp tasks
- Reads CONTEXT, ARCHITECTURE, CONVENTIONS, and the linked ClickUp task at the start of every session
- Writes code, runs tests, opens PRs
- One AI owns a branch start to merge — no mid-stream handoffs
- PRs always use the template; acceptance criteria pasted verbatim from ClickUp

### Codex (in GitHub)
- Reviews PRs against acceptance criteria in the PR body
- Reads [`REVIEW_GUIDE.md`](REVIEW_GUIDE.md) at the start of every review
- Marks each criterion Met / Not Met / Unclear with evidence
- Approves only when all criteria are Met
- Never merges. Approval necessary but not sufficient.

## Communication pattern
AIs do not talk to each other directly. Communication is through artifacts:
- **Code and config** in Git
- **Decisions** in `/docs/adr/`
- **Tasks and state** in ClickUp
- **PR bodies** carry acceptance criteria for the reviewer

When switching context to a new AI, brief it with what's *in the artifacts*, not what the previous AI said.

## Standard flow
1. Claude (chat) creates ClickUp story + subtasks with acceptance criteria
2. Caleb assigns work to Claude Code
3. Claude Code reads CONTEXT, ARCHITECTURE, CONVENTIONS, ClickUp task
4. Claude Code creates a branch, implements, opens a PR using the template
5. Codex reads REVIEW_GUIDE and reviews against pasted criteria
6. Codex approves or requests changes
7. Caleb does final review and merges

## Failure modes

**Confidently wrong about what other AIs did.** An AI won't verify what another AI claimed unless told to. Brief based on artifacts.

**Rubber-stamp reviews.** Codex may approve quickly on large PRs. The fix: explicit criterion-by-criterion review, not "looks good." If a review doesn't address every criterion, Caleb requests a redo.

**Stale criteria.** If criteria change in ClickUp after a PR opens, the PR body must be updated.

**Vague criteria.** "Service handles webhooks reliably" can't be reviewed. "Service returns 200 on valid webhooks, writes to Postgres within 500ms, returns 400 on invalid signatures" can.

**Scope creep flagged as missing.** Codex may say "this PR is missing X" when X was deferred. Fix: clear "Out of scope for this PR" notes in the PR description.

## When AIs disagree
- Document the disagreement explicitly (PR comment, ADR, or task comment)
- Caleb adjudicates
- Architectural decisions go into an ADR

## When this document is wrong
Update it. The doc must match reality.
