---
description: Quick exploratory spike before committing to TDD. Use when architect identifies unknowns, unfamiliar APIs, or ambiguous behavior that needs hands-on testing first.
argument-hint: [spike-topic]
---

# Prototype / Spike

You are running a quick prototype (spike) to explore unknowns before committing to a specification and TDD cycle. This is explicitly sloppy — no tests, no docs, no production quality required.

## Purpose

Reveal how an API, integration, or pattern actually behaves before investing in a full implementation. The output is **knowledge**, not code.

## When This Phase Is Needed

The `/architect` subagent should recommend prototyping when:

- Using an API or library for the first time in this project
- The API has known behavioral quirks or undocumented edge cases
- The integration involves multiple services interacting in ways we haven't tested
- Documentation is ambiguous or incomplete about a specific behavior
- The feature involves real-time protocols (WebSocket, streaming, event-driven patterns)

## What to Do

1. **Identify the unknowns** — What specific questions need answers?
2. **Build the minimum** — Smallest possible code that exercises the unknown behavior
3. **Test against the real service** — Use real API calls, not assumptions from docs
4. **Record what you learned** — Write a short "Spike Results" note

## Rules

- **No tests required** — This is throwaway code
- **No documentation required** — Just the spike results note
- **No code review** — Speed over quality
- **DO clean up** — Delete or `.gitignore` prototype files when done
- **DO use real APIs** — Never simulate or mock behavior you're trying to understand

## Output Format

```markdown
## Spike Results: [Topic]

### Questions Investigated
1. [Question 1]
2. [Question 2]

### Findings
1. [Answer to Q1 — with evidence]
2. [Answer to Q2 — with evidence]

### Surprises / Gotchas
- [Anything unexpected that should inform the spec]

### Recommendation
[PROCEED to /spec | REDESIGN the approach | ESCALATE to user]

### Prototype Code Location
[Path to throwaway code, or "deleted" if cleaned up]
```

## After the Spike

- Pass the spike results to `/spec` as input context
- Add any discovered gotchas to the relevant domain CLAUDE.md
- If a gotcha is cross-cutting, add it to the Architectural Invariants section in root CLAUDE.md
- Delete prototype code (it served its purpose)

---

## Current Request

<user_request>
$ARGUMENTS
</user_request>
