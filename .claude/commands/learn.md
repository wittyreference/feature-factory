---
description: Knowledge synthesis and articulation practice. Use when user wants to catch up on recent changes, practice explaining decisions, test gotcha knowledge, or build elevator-pitch fluency.
argument-hint: [briefing|decision|gotcha|narrative|trends|quiz|status|list|skip|review|generate]
---

# Learning & Knowledge System

Build and maintain deep comprehension of the project — its architecture, decisions, gotchas, capabilities, and evolution.

## Two Mindsets

**Catch-up**: "I've been away. What happened?" → `/learn briefing`
**Depth**: "I need to deeply understand and articulate X." → `/learn decision`, `/learn gotcha`, `/learn narrative`

## Rules

- **Code exercises** (no-args mode): Max 2 per session — unchanged
- **All other modes**: No session cap — these serve information retrieval and articulation practice
- **Exercise-first, answer-second**: For decision, gotcha, and narrative modes — pose the challenge BEFORE revealing the answer. This is the generation effect.
- **Source-grounded feedback**: Every piece of feedback cites the actual source document and path
- **Grep-first**: Given large files, always grep or read limited sections — never full-file reads
- **Decline = suppress**: Only applies to code exercises, not other modes

## Arguments

<user_request>
$ARGUMENTS
</user_request>

## Mode Dispatch

Parse the first word of `$ARGUMENTS`:

| First word | Mode |
|------------|------|
| *(empty)* | Code exercises (existing behavior) |
| `briefing` or `catch-up` or `catchup` | Briefing |
| `decision` | Decision deep-dive |
| `gotcha` | Gotcha scenario exercise |
| `narrative` or `articulate` or `pitch` | Narrative practice |
| `trends` or `patterns` | Cross-run trend analysis |
| `quiz` | Rapid-fire knowledge check |
| `status` or `dashboard` | Learning coverage dashboard |
| `list` | List pending exercises (existing) |
| `skip` | Suppress code exercises (existing) |
| `review` | Retrieval practice (existing, expanded) |
| `generate` | Generate exercises (existing, expanded) |

---

## Mode: Code Exercises (no arguments)

Existing behavior — unchanged.

1. Read `.meta/learning/exercises.md` for pending exercises
2. Read `.meta/learning/exercise-state.json` for session state
3. If `exercises_declined` is true, say "Exercises suppressed for this session. Use `/learn review` for retrieval practice on past topics, or try `/learn briefing` to catch up."
4. If `exercises_completed` >= 2, say "Session cap reached (2/2). Try `/learn decision`, `/learn gotcha`, or `/learn narrative` for other learning modes."
5. If no pending exercises, say "No exercises pending. Try `/learn briefing` for a catch-up, `/learn decision` to study a design decision, or `/learn gotcha` for scenario practice."
6. Otherwise, show the list of pending exercises (title + file path) and ask which one to work on
7. When the user picks one, present the exercise question and STOP. Wait for their response.
8. After their response, provide feedback:
   - Read the actual file referenced in the exercise
   - Compare their prediction/understanding to what the code actually does
   - If they were wrong, say so directly, explain the gap, explore why
   - If they were right, confirm and optionally add deeper context
9. After feedback, move the exercise to `.meta/learning/completed.md` with the user's response and your feedback
10. Update `exercise-state.json`: increment `exercises_completed`, add topic to `topics_covered`

---

## Mode: Briefing

"What happened while I was away?"

### Parse arguments

After the `briefing` keyword, check for:
- `Nd` (e.g., `5d`) → use N days as the window
- `since YYYY-MM-DD` → use that date as the start
- Nothing → read `.meta/learning/last-briefing.json` for `last_briefing_ts`. If 0 or missing, default to 3 days ago.

### Gather (read-only, grep-first)

1. **Git log**: Run `git log --oneline --since="YYYY-MM-DD" --no-merges`. Group commits by conventional prefix:
   - `feat:` → Features
   - `fix:` → Fixes
   - `docs:` → Documentation
   - `refactor:` / `chore:` / `style:` / `test:` → Maintenance
   - Unprefixed → Other

2. **New design decisions**: Run `git log --since="YYYY-MM-DD" -p -- DESIGN_DECISIONS.md` and look for newly added `## Decision` headers. If git diff is too noisy, compare the decision count with the count stored in `.meta/learning/generation-state.json`.

3. **New learnings**: Read `.meta/learnings.md`. Filter entries by their `## [YYYY-MM-DD]` date headers — only include those within the window.

4. **Validation reports**: List files in `.meta/validation-reports/` whose filenames start with dates in the window (format: `YYYY-MM-DD-*`). For each matching report, read only the first 30 lines to extract the summary.

5. **Review reports**: List directories in `.meta/review-reports/` sorted by date (newest first). For the 2-3 most recent, look for a synthesis file and read its first 40 lines.

6. **Platform updates**: Read `.claude/.update-cache/changelog-digest.md` if it exists — show the headline items.

### Synthesize and present

```markdown
## Briefing: [start date] → [today]

### Headlines
- [most significant change — a feature, decision, or finding]
- [second most significant]
- [third if warranted]

### Commits ([N] total)
**Features**: [one line per feat: commit]
**Fixes**: [one line per fix: commit]
**Docs/Maintenance**: [one line per remaining commit, or "N docs, N refactors"]

### New Design Decisions
- D[N]: [title] — [one-line rationale]
(or "None in this period")

### Validation & Review Findings
- [date] [type]: [N] findings ([severity breakdown])
  - Key: [top 2-3 findings]
(or "No validation runs in this period")

### New Learnings
- [date]: [topic] — [one-line summary]
(or "None captured")

### Platform Updates
- [headline items from changelog digest]
(or "No updates")
```

After presenting: "Want to drill into any of these? Pick a number, topic, or decision."

### Update state

Write to `.meta/learning/last-briefing.json`:
```json
{
  "last_briefing_ts": <current unix timestamp>,
  "last_briefing_date": "YYYY-MM-DD",
  "briefings_given": <previous + 1>
}
```

---

## Mode: Decision Deep-Dive

"Help me deeply understand and explain a design decision."

### Parse arguments

After the `decision` keyword:
- A number (e.g., `1`, `13`, `45`) → look up that specific decision
- A keyword (e.g., `tdd`, `risk`, `testing`) → grep `DESIGN_DECISIONS.md` for matching decision titles
- Nothing → show the full decision index

### No argument: Decision Index

Grep `DESIGN_DECISIONS.md` for all `## Decision` headers. Present as a numbered table:

```
| # | Title | Status |
|---|-------|--------|
| 1 | Some Design Decision | Active |
| 2 | Another Decision | Active |
| ... | ... | ... |
```

Say: "Pick a number to study, or search by keyword: `/learn decision testing`"

### Specific decision: Teaching Format

1. Read the specific `## Decision N:` section from `DESIGN_DECISIONS.md` (grep for the header, then read ~80 lines from that offset)
2. Restructure into teaching format:

```markdown
## Decision [N]: [Title]

### The Problem
[Restate the Context section in plain language — what situation forced this choice?]

### What We Chose
[The Decision, stated succinctly]

### Why (The Trade-Off)
[The Rationale — emphasize what we GAVE UP by choosing this. Every decision has a cost.]

### What This Means in Practice
[The Consequences section, with concrete examples of how this decision shows up in the codebase]

### Elevator Pitch (2 sentences)
[A concise articulation suitable for explaining to an SME in a hallway conversation]
```

3. Pose a comprehension exercise. Pick one:
   - "If someone asked you [scenario that tests understanding of the trade-off], what would you say?"
   - "Someone proposes [alternative that this decision rejected]. What's your counterargument?"
   - "When would this decision be WRONG? Under what circumstances should we revisit it?"

4. **STOP and wait for the user's response.**

5. After the user responds, provide feedback:
   - Compare their answer to the documented rationale and consequences
   - Cite specific passages from the decision document
   - If they missed the key trade-off, highlight it directly
   - If they nailed it, confirm and add nuance from related decisions

6. Update `.meta/learning/decision-coverage.json`: add the decision number to `decisions_exercised`, update `last_decision_exercise_ts`

---

## Mode: Gotcha Scenario Exercise

"Test whether I've internalized our operational gotchas."

### Parse arguments

After the `gotcha` keyword:
- A domain name (e.g., a directory or subsystem name) → scope to that domain
- A specific topic keyword → grep across gotcha sources for matches
- Nothing → pick a random unexercised gotcha

### Gather gotchas

Sources (search in order):
1. `.claude/references/operational-gotchas.md` — cross-cutting gotchas organized by category
2. Domain CLAUDE.md files — domain-specific gotcha sections
3. `.claude/rules/*-invariants.md` — architectural invariant rules

If a domain was specified, grep all sources for that domain keyword. Otherwise, pick a random gotcha that isn't in `.meta/learning/gotcha-coverage.json`'s `gotchas_exercised` list.

### Present as scenario

DO NOT reveal the gotcha. Instead, construct a realistic debugging scenario:

1. Read the gotcha entry fully to understand the mechanism
2. Frame it as a situation the user might encounter:
   - "You just deployed [X] and [symptom]. The code looks correct. What's happening?"
   - "A user reports [symptom] but only on [condition]. Where would you look?"
   - "Your [operation] returns [error code]. The docs say this means [X], but that doesn't match your setup. What's actually going on?"
3. **STOP and wait for the user's response.**

### Provide feedback

After the user responds:
- If they identified the gotcha (or close enough): Confirm, add the deeper context and mechanism from the source
- If they missed it: Reveal the gotcha directly, explain the mechanism, quote the relevant source
- Cross-reference: If related gotchas exist, mention them
- Cite the source: "Documented in `.claude/references/operational-gotchas.md` under [section]" or "See `[domain]/CLAUDE.md` → Gotchas"

### Generate fingerprint and update state

Create a fingerprint from the gotcha (lowercase, remove punctuation, first 6 words, join with hyphens). Add to `.meta/learning/gotcha-coverage.json`'s `gotchas_exercised` list. Update `last_gotcha_exercise_ts`.

---

## Mode: Narrative Practice

"Help me practice articulating what this project is and why it matters."

### Gather narrative sources

Read (headers and key sections only, not full files):
1. Project README or executive summary
2. Demo scripts or talking points (if they exist in `.meta/`)
3. Design decisions summary
4. Most recent updates or capability docs

### Pick an exercise type

Read `.meta/learning/narrative-state.json` for `exercises_done`. Rotate through types that haven't been done recently:

#### Type 1: Elevator Pitch
Pick a persona (rotate: engineer, PM, VP of Engineering, CTO, developer advocate):
"In 60 seconds, explain what this project is to [persona]. Focus on what matters to THEM."
STOP. Wait for response.
Feedback: Compare against project summary and key messages. Did they hit the right value props for that persona? Did they quantify impact? Was the framing appropriate for the audience?

#### Type 2: Feature Spotlight
Pick a specific capability from the project:
"Explain [capability] — what it does, how it works at a high level, and why it matters for the project's positioning."
STOP. Wait for response.
Feedback: Compare against the relevant source documentation. Check for accuracy of technical claims. Flag any outdated numbers or capabilities.

#### Type 3: Objection Handling
Pick a realistic objection (rotate):
- "This seems over-engineered for what it does."
- "Why not just use [common alternative]?"
- "How do you know the autonomous work is correct?"
- "How does this scale?"
STOP. Wait for response.
Feedback: Evaluate against the design decisions that address these concerns. Suggest stronger framing if needed.

#### Type 4: Numbers Game
Ask the user to recall 5 specific quantitative claims without looking them up:
- How many design decisions?
- How many operational gotchas?
- How many safety hooks?
- How many domain skills?
- How many test suites?
STOP. Wait for response.
Score: X/5 correct. For misses, provide the current accurate number and its source.

#### Type 5: Why This Decision?
Frame a technical question an informed person would ask (rotate):
- "Why enforce TDD for this project?"
- "Why not use mocks in testing?"
- "What's the point of the risk model?"
STOP. Wait for response.
Feedback: Compare against the specific design decision and its documented rationale.

### Update state

Add the exercise type and persona/topic to `.meta/learning/narrative-state.json`'s `exercises_done` list. Update `last_narrative_ts`.

---

## Mode: Trends

"What themes keep recurring across our validation and review runs?"

This mode is pure synthesis — no exercise, no STOP.

### Gather

1. List files in `.meta/validation-reports/` sorted by date (newest first). Read the first 80 lines of the 3-5 most recent reports to capture summaries and priority findings.
2. List directories in `.meta/review-reports/` sorted by date (newest first). For the 2-3 most recent, look for a synthesis/summary file and read its first 60 lines.
3. Check for any hostile review reports in `.meta/review-reports/` or `.meta/` — read their summary findings sections.

### Synthesize

Look for patterns across the collected findings:

```markdown
## Trend Analysis: [date range of reports analyzed]

### Recurring Unresolved Themes
[Issues flagged in 2+ reports that haven't been addressed yet]
- **[theme]**: Seen in [report1], [report2]. Status: unresolved.

### Resolved Themes
[Issues from earlier reports that later reports no longer flag]
- **[theme]**: First seen [date], resolved by [date]. How: [brief].

### Emerging Themes
[Issues appearing only in the most recent report — too early for pattern but worth watching]
- **[theme]**: First seen [date]. Context: [brief].

### Strongest Validated Capabilities
[Features or qualities consistently praised across reviewers and runs]
- **[capability]**: Validated by [N] sources ([list]).

### Coverage Gaps
[Areas not covered by recent validation — domains skipped, scenarios untested]
```

---

## Mode: Quiz

"Quick self-test across knowledge areas."

### Parse arguments

After `quiz`: optional topic keyword to scope questions. No argument = sample across all sources.

### Generate 5 questions

Draw from multiple knowledge sources:
1. A design decision question: "What did we decide about [X] and why?"
2. A gotcha question: "What happens if [scenario]?"
3. A quantitative question: "How many [X] does the project have?"
4. A capability question: "What does [feature] do?"
5. A recent-change question: "What changed in the last week regarding [area]?" (requires git log)

Present all 5 at once. STOP. Wait for the user to answer (brief answers are fine).

Score and provide corrections for each miss. Cite sources.

---

## Mode: Status (Dashboard)

Show learning coverage across all knowledge sources.

### Gather metrics

1. **Code exercises**: Count pending in `.meta/learning/exercises.md` (count `## ` headers). Count completed in `.meta/learning/completed.md`. Read `exercise-state.json` for `topics_covered`.
2. **Briefings**: Read `.meta/learning/last-briefing.json` for `last_briefing_date` and `briefings_given`. Run `git rev-list --count --since="LAST_BRIEFING_DATE" HEAD` for commits since.
3. **Decisions**: Count `## Decision` headers in `DESIGN_DECISIONS.md`. Read `.meta/learning/decision-coverage.json` for `decisions_exercised`.
4. **Gotchas**: Grep-count gotcha entries in `.claude/references/operational-gotchas.md` (count `###` or `**` bold entries). Read `.meta/learning/gotcha-coverage.json` for `gotchas_exercised`.
5. **Narratives**: Read `.meta/learning/narrative-state.json` for `exercises_done`. Total types = 5.
6. **Trends**: Check date of most recent file in `.meta/validation-reports/` to estimate last analysis.

### Present dashboard

```
## Learning Status

| Area | Coverage | Last Activity |
|------|----------|---------------|
| Code exercises | N pending, N completed | [date or "never"] |
| Briefings | N given, N commits since last | [last briefing date] |
| Decisions | N/M exercised (N%) | [date or "never"] |
| Gotchas | N/M exercised (N%) | [date or "never"] |
| Narrative types | N/5 practiced | [date or "never"] |
| Trend analysis | [last report date] | — |

### Suggested next action
[Based on the biggest gap — e.g., "You've never done a briefing. Try `/learn briefing`." or "Only 3/M decisions exercised. Try `/learn decision`." or "Last briefing was 5 days ago with 23 commits since. Time for `/learn briefing`."]
```

---

## Mode: List (existing — unchanged)

Show all pending exercises from `.meta/learning/exercises.md` without starting one. Include:
- Exercise type (Prediction, Generation, Trace, Debug, Decision, Gotcha, Diagnosis)
- File path or knowledge source
- When it was generated
- Source session

---

## Mode: Skip (existing — unchanged)

Mark code exercises as declined for this session:
1. Update `.meta/learning/exercise-state.json`: set `exercises_declined` to true
2. Confirm: "Code exercises suppressed for this session. Other modes still available: `/learn briefing`, `/learn decision`, `/learn gotcha`, `/learn narrative`."

---

## Mode: Review (existing — expanded)

Retrieval practice on previously covered topics. Now draws from ALL completed learning, not just code exercises.

1. Read `.meta/learning/completed.md` for code exercise topics
2. Read `.meta/learning/decision-coverage.json` for exercised decisions
3. Read `.meta/learning/gotcha-coverage.json` for exercised gotchas
4. Read `.meta/learning/narrative-state.json` for practiced narratives
5. Pick a topic from ANY of these sources (prefer older topics for spacing effect)
6. Ask a recall question about that topic — NOT the same question as the original exercise, but related
7. STOP and wait for the user's response
8. Provide feedback, citing the original source

---

## Mode: Generate (existing — expanded)

Force regeneration of exercises from multiple knowledge sources.

### Step 1: Existing session log processing (unchanged)

1. Read `.meta/learning/session-log.jsonl`
2. Generate code exercise stubs (Prediction, Generation, Trace, Debug)
3. Clear `session-log.jsonl` after processing

### Step 2: Non-code knowledge scanning (new)

Read `.meta/learning/generation-state.json` for previous scan state.

1. **New decisions**: Count `## Decision` headers in `DESIGN_DECISIONS.md`. Compare to `decisions_count_at_generation`. For each NEW decision (by number), generate a "Generation > Comparison" exercise:
   ```
   ## Generation > Comparison (Decision)
   - **Source:** `DESIGN_DECISIONS.md` — Decision [N]: [title]
   - **Generated:** [timestamp]

   **Exercise:** [Brief context of the problem]. How would YOU approach this? Write your approach, then we'll compare with the actual decision.
   ```

2. **New learnings**: Read `.meta/learnings.md`. Find entries with dates after `learnings_scanned_through`. For entries containing signal words (gotcha, quirk, workaround, edge case, actually), generate a "Predict the Gotcha" exercise:
   ```
   ## Predict the Gotcha
   - **Source:** `.meta/learnings.md` — [date] [topic]
   - **Generated:** [timestamp]

   **Exercise:** [Describe the scenario from the learning without revealing the resolution]. What would you expect to happen? What's the gotcha?
   ```

3. **New validation findings**: List files in `.meta/validation-reports/` not in `validation_reports_scanned`. For each new report, read its first 30 lines. If blocking/major findings exist, generate a "Diagnosis" exercise:
   ```
   ## Diagnosis (Validation)
   - **Source:** `.meta/validation-reports/[filename]`
   - **Generated:** [timestamp]

   **Exercise:** A validation run found [symptom/category]. What do you think the root cause is? What would you check first?
   ```

### Step 3: Update generation state

Write to `.meta/learning/generation-state.json`:
```json
{
  "last_generation_ts": <current unix timestamp>,
  "decisions_count_at_generation": <current count>,
  "learnings_scanned_through": "YYYY-MM-DD",
  "validation_reports_scanned": [<all report filenames>]
}
```

Report total exercises generated (code + non-code).

---

## Important

- All modes require `.meta/` (meta-development mode). If `.meta/` doesn't exist, say so and exit.
- The exercise question is the point of engagement. Never dilute it with hints or partial answers before the user responds.
- Be direct in feedback. If the user's understanding is wrong, say so. Genuine correction is more valuable than false validation.
- Always cite the source document and path when providing feedback.
- For `/learn briefing` and `/learn trends`, prefer concise synthesis over exhaustive data dumps.
