# Context Fundamentals for Development

This skill teaches core context engineering principles applied to software development.

## Core Concept

Context engineering is the holistic curation of all information that enters the model's limited attention budget. Effective context engineering means finding the smallest set of high-signal tokens that maximize the likelihood of desired outcomes.

## The Development Context Challenge

Software development involves multiple context sources that compete for attention:

| Context Source | Size | Signal Value |
|----------------|------|--------------|
| CLAUDE.md files | ~500 lines each | High - project standards |
| API responses | 20+ fields | Medium - most fields unused |
| Code files | 10-500+ lines | Medium - structure matters |
| Error logs | Variable | High when debugging |
| Test output | 50-500 lines | Low after passing |

## When to Load Context

### Starting a New Feature

Load:
- Root `CLAUDE.md` (always loaded automatically)
- Relevant subdirectory `CLAUDE.md` (e.g., `src/handlers/CLAUDE.md`)
- Similar existing function as pattern reference

Avoid loading:
- Unrelated CLAUDE.md files
- Full test suites
- Historical git logs

### Debugging a Failure

Load:
- Error log output (recent errors only)
- The failing function code
- Related test file
- Relevant error code reference

Avoid loading:
- Full request/response history
- Unrelated function files
- Passing test output

### Long Development Sessions

After 10+ exchanges:
- Summarize progress so far
- Drop resolved discussion threads
- Keep only active file contents
- Retain key decisions made

## Context Efficiency Patterns

### API Response Context

Full response (low efficiency):
```json
{
  "id": "usr_abc123",
  "email": "user@example.com",
  "name": "Jane Doe",
  "created_at": "2025-01-15T10:23:45Z",
  "updated_at": "2025-06-20T14:30:00Z",
  "status": "active",
  "role": "admin",
  "team_id": "team_xyz789",
  "last_login": "2025-06-20T08:15:00Z",
  "preferences": { "theme": "dark", "notifications": true, "timezone": "America/New_York" },
  "permissions": ["read", "write", "admin"],
  "subscription": { "plan": "enterprise", "expires_at": "2026-01-15T00:00:00Z" }
}
```

Essential context (high efficiency):
```
User usr_abc123: Jane Doe (admin, active)
Enterprise plan, team_xyz789
```

### Code Response Context

Full output (low efficiency):
```
HTTP/1.1 200 OK
Content-Type: application/json
X-Request-Id: req_abc123
X-Rate-Limit-Remaining: 98
Date: Mon, 15 Jan 2025 10:23:45 GMT
Content-Length: 1234

{"status": "success", "data": { ... }}
```

Compressed context (high efficiency):
```
200 OK: success response (req_abc123, 98 rate-limit remaining)
```

### Function Context

When referencing a function, include:
- ABOUTME comments (2 lines)
- Handler signature
- Key logic branches
- Return/callback patterns

Omit:
- Import statements (unless debugging)
- Boilerplate error handling
- Comments explaining obvious code

## Context Budget Guidelines

| Task Type | Recommended Context Size |
|-----------|-------------------------|
| Simple bug fix | 1 file + error message |
| New function | Pattern file + CLAUDE.md |
| Feature with tests | 2-3 files max |
| Complex refactor | 4-5 files, summarized |
| Full workflow | Use orchestrator, load per-phase |

## Key Practices

1. **Load on demand**: Don't pre-load all CLAUDE.md files; load relevant ones when entering that domain

2. **Summarize frequently**: After completing a sub-task, summarize what was done before moving on

3. **Drop resolved context**: Once a test passes, the full test output is no longer needed

4. **Preserve decisions**: Keep key architectural decisions even when dropping implementation details

5. **Use references**: Instead of loading full files, reference them: "See `src/handlers/CLAUDE.md` for handler patterns"

6. **Consult doc-map first**: Check `.claude/references/doc-map.md` before starting work to identify which docs to load for the current operation

## Documentation Flywheel

The project uses a file-based documentation flywheel:

1. **Before acting**: Consult doc-map.md to identify relevant docs
2. **During work**: Hooks track files changed
3. **After completing**: Hooks write suggestions to `pending-actions.md`
4. **Before commits**: Read `pending-actions.md` and address suggestions

This ensures knowledge is captured and promoted to permanent documentation.

## Anti-Patterns to Avoid

- Loading all source files "just in case"
- Keeping full error logs after the error is fixed
- Including passing test output in ongoing context
- Loading multiple CLAUDE.md files simultaneously
- Repeating the same context in every message
