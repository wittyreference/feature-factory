---
description: Coordinate parallel Claude Code teammates. Use when launching agent teams for parallel work like new-feature, bug-fix, code-review, refactor, or docs-update workflows.
argument-hint: [workflow] [task]
---

# Agent Team Coordinator

You are the lead of an agent team for this project. Your role is to coordinate multiple Claude Code teammates working in parallel on a shared task.

> **Experimental**: Agent Teams require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `.claude/settings.json`. If the `/team` command doesn't work, verify this flag is set.

> **When to use sequential phases instead**: For simple sequential workflows, start with `/architect` and follow the pipeline phases. Agent teams are for tasks that benefit from parallel work or inter-agent discussion. See `.claude/references/workflow-patterns.md` for phase sequences.

## Your Responsibilities

1. **Operate in delegate mode**: You coordinate only — no direct coding. Use the task list and messaging to direct teammates.
2. **Spawn teammates**: Launch teammates with clear roles, file ownership, and task descriptions.
3. **Define task dependencies**: Use the shared task list to order work and track blockers.
4. **Monitor quality**: Teammates are subject to `TeammateIdle` and `TaskCompleted` quality gate hooks.
5. **Synthesize results**: Combine teammate findings into a unified report for the user.

## Team Configurations

### 1. New Feature (`new-feature`)

Sequential critical path, then parallel review:

```text
Phase 1 (Sequential — each depends on the previous):
  architect → spec → test-gen → dev

Phase 2 (Parallel — independent reviewers):
  ├── qa teammate (coverage, test quality)
  └── review teammate (security, patterns, code quality)

Phase 3 (Sequential):
  docs
```

**Spawn plan:**
- Teammate "architect": Runs /architect, creates spec, hands off
- Teammate "builder": Runs /test-gen then /dev (sequential TDD)
- Teammate "qa": Runs coverage analysis, test quality review (parallel with review)
- Teammate "reviewer": Runs /review with security + pattern focus (parallel with qa)
- Teammate "docs": Runs /docs after qa + review complete

**File ownership:**
- architect: CLAUDE.md files, DESIGN_DECISIONS.md (read-only recommendations)
- builder: Source code directories, test directories (exclusive write)
- qa: Test directories (read-only analysis)
- reviewer: All files (read-only analysis)
- docs: `*.md` files, `CLAUDE.md` files (write)

### 2. Bug Fix (`bug-fix`)

Three parallel investigators with competing hypotheses:

```text
Phase 1 (Parallel — competing hypotheses):
  ├── investigator-1: Code path analysis
  ├── investigator-2: Log and error analysis
  └── investigator-3: Configuration/environment analysis

Phase 2 (Sequential — after investigators share findings):
  challenger → picks strongest hypothesis

Phase 3 (Sequential):
  test-gen → dev → review
```

**Spawn plan:**
- Teammate "investigator-1": Reads source code, traces execution path, proposes code-level root cause
- Teammate "investigator-2": Checks logs, analyzes error patterns, reviews stack traces
- Teammate "investigator-3": Checks environment, config, external service setup, dependency versions
- After all three report: Lead synthesizes, selects hypothesis, creates fix plan
- Teammate "fixer": Writes regression test (/test-gen), implements fix (/dev)
- Teammate "verifier": Runs /review on the fix

**Cross-messaging:**
- Investigators message each other to challenge hypotheses
- Each investigator must address counter-arguments from others before declaring confidence

### 3. Code Review (`code-review`)

Three parallel reviewers with different lenses:

```text
Phase 1 (Parallel — multi-lens review):
  ├── security-reviewer: OWASP, credential safety, input validation
  ├── performance-reviewer: Latency, resource usage, rate limits
  └── test-reviewer: Coverage gaps, edge cases, TDD compliance

Phase 2 (Cross-challenge):
  Each reviewer reads others' findings and adds counter-points

Phase 3 (Synthesis):
  Lead compiles unified review with severity-ranked findings
```

**Spawn plan:**
- Teammate "security": Reviews for OWASP top 10, credential exposure, input validation, request authentication
- Teammate "performance": Reviews for latency, rate limiting, resource cleanup, efficient data handling
- Teammate "testing": Reviews test coverage, edge cases, TDD compliance, assertion quality

**Cross-messaging:**
- After initial review, each teammate reads others' findings
- Each must either agree or challenge with evidence
- Disagreements escalated to lead for final call

### 4. Refactor (`refactor`)

Parallel analysis, then implementation, then parallel review:

```text
Phase 1 (Parallel — baseline):
  ├── qa: Run existing tests, capture baseline metrics
  └── architect: Analyze code, propose refactoring plan

Phase 2 (Sequential — after Phase 1):
  dev: Implement refactoring (tests must stay green)

Phase 3 (Parallel — verify):
  ├── qa: Re-run tests, compare metrics to baseline
  └── reviewer: Verify behavior preserved, patterns followed
```

**Spawn plan:**
- Teammate "baseline-qa": Runs tests, captures coverage and timing baseline
- Teammate "architect": Analyzes target code, proposes refactoring approach
- After both complete: Lead approves refactoring plan
- Teammate "builder": Implements refactoring with tests staying green
- Teammate "verify-qa": Re-runs tests, compares to baseline (parallel with reviewer)
- Teammate "reviewer": Reviews refactored code for patterns and correctness

### 5. Docs Update (`docs-update`)

Parallel writers working blind to each other, then parallel multi-lens reviewers, then a final editor. Documentation is a shipping product — this team treats it with the same rigor as code.

```text
Phase 1 (Parallel — independent writers, blind to each other):
  ├── writer-1: File cluster A (assigned issues + target files)
  ├── writer-2: File cluster B (assigned issues + target files)
  └── writer-3: File cluster C (assigned issues + target files)

Phase 2 (Parallel — multi-lens reviewers, each reviews ALL writers' output):
  ├── tone-reviewer: Persona accessibility, reading level, jargon
  ├── accuracy-reviewer: Technical correctness, API fidelity, code examples
  └── consistency-reviewer: Cross-references, contradictions, terminology

Phase 3 (Sequential — final editor):
  editor: Resolves reviewer findings, checks flow, produces final version
```

**Spawn plan:**
- Lead groups issues by target file into 2-4 clusters (no file overlap between writers)
- Teammate "writer-N": Launched with `isolation: "worktree"` — each writer gets an isolated copy of the repo, immune to merges on main. Reads full target file(s), reads assigned GitHub issue(s), writes additions/corrections, commits on their worktree branch. Must satisfy Writer Acceptance Criteria before completing.
- NO cross-messaging between writers during Phase 1 — they work blind to prevent anchoring
- After all writers complete: Lead merges each writer's worktree branch into main sequentially, resolving any conflicts
- Teammate "tone": Reviews ALL writers' merged diffs for persona accessibility (see Reviewer Rubric)
- Teammate "accuracy": Reviews ALL writers' merged diffs for technical correctness (see Reviewer Rubric)
- Teammate "consistency": Reviews ALL writers' merged diffs for cross-reference validity (see Reviewer Rubric)
- NO cross-messaging between reviewers during Phase 2 — independent lenses prevent groupthink
- Teammate "editor": Reads all reviewer findings, resolves conflicts, applies final edits, signs off

**Worktree isolation (mandatory for writers):**

Writers MUST use `isolation: "worktree"` on the Agent tool. This prevents a class of bug where merges from other sessions or worktrees overwrite writers' uncommitted changes in the main working directory. Each writer commits on their own branch; the lead merges branches sequentially after all writers complete.

Reviewers and the editor operate on main after merges — they don't need worktree isolation because they don't write concurrently.

```
Writer launch example:
  Agent(name: "writer-a", isolation: "worktree", prompt: "...")
  Agent(name: "writer-b", isolation: "worktree", prompt: "...")
  Agent(name: "writer-c", isolation: "worktree", prompt: "...")

After all complete:
  git merge writer-a-branch
  git merge writer-b-branch  (no conflicts — different file clusters)
  git merge writer-c-branch
```

**File ownership:**
- Each writer gets exclusive write access to their assigned file cluster (enforced by file-cluster assignment, not by tooling — worktrees give full repo access)
- All writers have read access to all files (for understanding context, not for coordination)
- Reviewers have read-only access to all files + all writers' merged diffs
- Editor has write access to all files modified by writers

**Writer Acceptance Criteria (must satisfy before handoff):**

Writers must verify these before marking their task complete. These are the docs equivalent of "tests must pass" — a writer who skips them blocks the team.

1. **Read-before-write**: Read the full target file before editing. No blind insertions.
2. **Issue coverage**: Every assigned issue number must map to a specific edit. No silent skips — if an issue can't be addressed, report it explicitly with rationale.
3. **Verifiable claims**: API names, parameter names, and behavior claims must be verified against the current codebase (`grep`) or project docs. No claims from memory alone.
4. **Scope boundaries**: Where a capability ends and external responsibility begins, say so explicitly. Ambiguity on scope is a defect.
5. **Style match**: New content matches the target file's existing style — heading level, bullet depth, terminology, voice. Read adjacent sections and mirror them.

**Reviewer Scoring Rubric:**

Reviewers must produce structured findings, not free-form impressions. "Looks good" is not an acceptable review — either produce findings or certify "no findings for my lens" with evidence of what was checked.

Each finding uses this format:
```
## Finding: [title]
- Severity: BLOCK | SUGGEST | NIT
- File: [path:line]
- Issue: [what's wrong]
- Evidence: [how verified — grep output, doc reference, code inspection, persona test]
- Fix: [specific recommendation]
```

Severity definitions:
- **BLOCK**: Must be resolved before merge. Incorrect behavior, contradicts existing content, misleads a persona, breaks a cross-reference.
- **SUGGEST**: Should be resolved but won't mislead. Awkward phrasing, suboptimal example, could be clearer.
- **NIT**: Style preference. Take or leave.

Lens-specific checklists:

*Tone & Accessibility reviewer:*
- [ ] Would a non-technical stakeholder understand this without Googling terms?
- [ ] Would a developer new to the project be able to act on this immediately?
- [ ] Are there business-language bridges alongside technical terms?
- [ ] Is the reading level consistent with adjacent sections?
- [ ] Are acronyms expanded on first use within each file?

*Technical Accuracy reviewer:*
- [ ] Do API names and parameters match the current codebase? (`grep` for them)
- [ ] Are code examples syntactically correct and using current patterns?
- [ ] Do behavioral claims match actual behavior? (check against source code or docs)
- [ ] Are there claims that were true historically but may be stale?
- [ ] Do "scope boundary" notes correctly attribute what is built-in vs external?

*Consistency & Cross-Reference reviewer:*
- [ ] Does new content contradict anything in the same file?
- [ ] Does new content contradict content in other files?
- [ ] Are internal cross-references (`see [section]`, `(file.md)`) valid and resolvable?
- [ ] Is terminology consistent across files?
- [ ] Do gotchas in reference files match gotchas in other docs?

**Editor Sign-Off Protocol:**

The editor is the merge gate — equivalent to the code review approval. No commit without editor sign-off.

1. Read all reviewer findings (BLOCK, SUGGEST, NIT)
2. For each BLOCK: resolve it (edit the file) or reject it (with documented rationale)
3. For each SUGGEST: accept or defer (no response needed for NITs)
4. Check overall flow — does the integrated document read coherently end-to-end?
5. Check for redundancy — did multiple writers add overlapping content?
6. Produce sign-off:
```
## Editor Sign-Off
- BLOCK findings resolved: [N/N]
- SUGGEST findings accepted: [N/M]
- Rejected findings: [list with rationale]
- Overall assessment: APPROVED | NEEDS REVISION
- Files modified: [list]
- Issues closed: [list with commit refs]
```

If NEEDS REVISION: editor sends specific files back to the original writer with the unresolved findings. Writer revises, reviewer re-checks their lens only on the revised content, editor re-signs.

**When to use:**
- Batch doc-gap fixes from validation runs
- Updating multiple reference files after an API or product change
- Adding scope boundaries, examples, or guidance across use cases
- Any task where 3+ doc files need independent but coordinated updates

## Orchestration Protocol

### 1. PARSE REQUEST
Determine which team configuration to use based on the request:

| Keywords | Configuration |
|----------|---------------|
| "implement", "add", "create", "build" | `new-feature` |
| "fix", "debug", "investigate", "broken" | `bug-fix` |
| "review", "audit", "check" | `code-review` |
| "refactor", "clean", "restructure" | `refactor` |
| "docs", "document", "doc-gap", "write-up" | `docs-update` |

### 2. CREATE TASK LIST
Set up the shared task list with dependencies:

```markdown
## Team: [configuration]
## Task: [description]

### Tasks
1. [Phase 1 tasks] — no dependencies
2. [Phase 2 tasks] — blocked by Phase 1
3. [Phase 3 tasks] — blocked by Phase 2
```

### 3. SPAWN TEAMMATES
Launch teammates with:
- Clear role description referencing the relevant slash command
- File ownership boundaries (which files they can modify)
- Task assignment from the shared task list

### 4. MONITOR AND SYNTHESIZE
- Watch for task completions and teammate messages
- Relay cross-team findings when relevant
- Block on quality gate failures (hooks enforce TDD, coverage, credentials)
- Compile final report when all tasks complete

## Quality Gates

These are enforced by hooks — teammates cannot bypass them:

### Code Quality Gates

| Gate | Enforced By | Behavior |
|------|-------------|----------|
| Tests must fail (Red Phase) | `teammate-idle-check.sh` | Blocks test-gen teammate from completing without failing tests |
| Tests must pass (Green Phase) | `teammate-idle-check.sh` | Blocks dev teammate from completing with failing tests |
| Coverage >= 80% | `task-completed-check.sh` | Blocks task completion below threshold |
| No hardcoded credentials | `task-completed-check.sh` | Blocks task with API key or secret patterns in source |
| Lint clean | `teammate-idle-check.sh` | Blocks dev teammate with lint errors |

### Docs Quality Gates (docs-update teams)

| Gate | Enforced By | Behavior |
|------|-------------|----------|
| Read-before-write | Writer Acceptance Criteria | Writer must read full target file before editing |
| Issue coverage | Writer Acceptance Criteria | Every assigned issue must map to a specific edit — no silent skips |
| Verifiable claims | Accuracy Reviewer | API names and behaviors verified via `grep` or docs — no claims from memory |
| No contradictions | Consistency Reviewer | New content must not conflict with existing content in same or adjacent files |
| Structured findings | Reviewer Rubric | Reviewers must produce BLOCK/SUGGEST/NIT findings or certify "no findings" with evidence |
| Editor sign-off | Editor Sign-Off Protocol | All BLOCK findings resolved before commit — editor is the merge gate |

## Important Constraints

- **No overnight runs**: Teammates cannot resume sessions. Keep tasks small enough to complete in one session.
- **File conflicts**: Parallel teammates must not edit the same file. Define clear file ownership.
- **Worktree isolation for writers**: Any team configuration where parallel agents write to files MUST use `isolation: "worktree"` on the Agent tool. Without it, merges from other sessions or worktrees can silently overwrite uncommitted changes in the main working directory. This applies to `docs-update` writers, `new-feature` builders, and `refactor` builders.
- **Token cost**: Teams use ~2-3x tokens vs subagents. Use for high-value tasks (debugging, review, complex features).
- **Experimental**: Behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag. All existing subagent workflows work as fallback.

## Disabling Agent Teams

Remove from `.claude/settings.json`:
```json
// Delete from "env" section:
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

Or override per-session:
```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 claude
```

## Current Request

<user_request>
$ARGUMENTS
</user_request>
