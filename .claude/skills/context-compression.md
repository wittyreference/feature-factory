---
name: context-compression
description: Context management and compression techniques. Use when optimizing context window usage, managing large sessions, or applying compression strategies for development.
---

# Context Engineering

Unified context management skill — fundamentals, compression techniques, and session optimization.

## Quick Reference: Compression Ratios

| Content Type | Ratio | Preserve | Drop |
|-------------|-------|----------|------|
| API responses | 5:1 | IDs, status, key fields relevant to task | Boilerplate, default attrs |
| JSON payloads | 4:1 | Structure shape, field count, key values | Redundant nesting, metadata |
| Test output (pass) | 10:1 | Count by category | Individual test names |
| Test output (fail) | 3:1 | Test name, expected vs received | Stack traces |
| Error logs | 5:1 | Error code, URL, count, timeframe | Duplicate entries |
| Conversation history | 8:1 | Decisions, files changed, current state | Implementation details |

## When to Compress

- API responses > 20 lines → `GET /endpoint → 200: { key fields }`
- JSON payloads > 5 fields → `User usr_abc: Jane Doe (admin, active)`
- Test output > 50 lines → `Tests: 12 passed (module-a: 4, module-b: 4, module-c: 4)`
- Error logs with repeats → `Error: POST /api/users 502 — 5 occurrences in 2 min`
- Session history > 10 exchanges → summarize progress, drop resolved threads

## Context Budget

| Task Type | Recommended Load |
|-----------|-----------------|
| Simple bug fix | 1 file + error message |
| New module | Pattern file + domain CLAUDE.md |
| Feature with tests | 2-3 files max |
| Complex refactor | 4-5 files, summarized |
| Full workflow | Use orchestrator, load per-phase |

## Loading Strategy

**Always loaded** (auto-loaded by Claude Code):
- Root CLAUDE.md, MEMORY.md

**Load on demand** (when entering domain):
- Domain CLAUDE.md (e.g., `src/auth/CLAUDE.md`)
- Similar existing module as pattern
- Relevant test file

**Avoid loading**:
- CLAUDE.md files for domains you're not touching
- Full test suites (just the relevant test)
- Historical git logs
- Passing test output (compress to counts)

## Session Optimization

**After 10+ exchanges**: Summarize progress, drop resolved discussions, keep decisions.

**Session summary format**:
```markdown
## Session Summary
### Completed: [tasks done]
### In Progress: [current work]
### Key Decisions: [choices made]
### Files Modified: [file list]
```

## When NOT to Compress

Keep full context when actively debugging, writing new code from a pattern, first encounter with an API, doing code review, or security auditing.

## Anti-Patterns

- Loading all CLAUDE.md files "just in case"
- Keeping full error logs after the bug is fixed
- Including passing test output in ongoing context
- Repeating the same context in every message
- Loading full API payloads when only key fields matter
