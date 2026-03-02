# Context Optimization

Optimize context for the current session. Load the `context-compression` skill for techniques.

## Actions

**`/context summarize`** — Summarize session progress: completed tasks, in-progress work, key decisions, files modified. Use after 10+ exchanges to free up context.

**`/context load [task]`** — Identify which domain CLAUDE.md, skills, and reference docs to load for a task. Avoid loading unrelated domains.

**`/context analyze`** — Audit current context efficiency: estimate token usage, flag candidates for removal, recommend compression.

## Quick Compression Reference

| Content | Compress To |
|---------|-------------|
| API responses | `GET /endpoint → 200: { key fields }` |
| Tests (pass) | `Tests: 12 passed (module-a: 4, module-b: 4, module-c: 4)` |
| Errors | `Error: POST /api/users 502 — 5x in 2 min` |
| JSON payloads | `User usr_abc: Jane Doe (admin, active)` |

For full techniques, load the `context-compression` skill.

$ARGUMENTS
