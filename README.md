# Feature Factory

A self-documenting, self-healing, TDD-enforcing development toolkit for [Claude Code](https://claude.ai/code).

Clone this repo. Run `init.sh`. Your codebase gets documentation that maintains itself, quality gates that enforce themselves, and a development pipeline that won't let you skip the hard parts.

## What This Is

Feature Factory is a collection of **hooks**, **commands**, **skills**, and **configuration** that turns Claude Code into a disciplined development partner. It enforces TDD, catches hardcoded credentials before they reach git, suggests documentation updates when your code changes, and generates learning exercises from autonomous work.

Every pattern in this toolkit was earned through real bugs, real oversights, and real "we should have caught that" moments — built over hundreds of sessions developing production software with Claude Code.

## What's Inside

### 16 Event-Driven Hooks

Hooks fire automatically on Claude Code events (file writes, bash commands, session lifecycle). They enforce quality without requiring you to remember to run checks.

| Hook | Event | What It Does |
|------|-------|-------------|
| `pre-write-validate` | Before file write | Blocks hardcoded credentials, enforces ABOUTME headers, meta-mode isolation |
| `post-write` | After file write | Tracks session files, triggers auto-lint, logs autonomous work events |
| `pre-bash-validate` | Before bash command | Blocks `--no-verify`, force-push to main, validates pre-deploy checks |
| `post-bash` | After bash command | Detects deploy completion, triggers doc flywheel after tests |
| `flywheel-doc-check` | After writes/tests | 5-source doc analysis: uncommitted files, commits, session tracking, patterns, drift |
| `session-start-log` | Session begins | Checks env vars, stale sessions, pending exercises, resets tracking |
| `session-checklist` | Session ends | Reminds about uncommitted work, unpushed commits, stale learnings |
| `task-completed-check` | Team task done | TDD compliance, coverage threshold, credential safety |
| `teammate-idle-check` | Teammate idle | Enforces Red/Green phase quality gates per task type |
| `generate-learning-exercises` | After autonomous work | Creates structured exercises from file creation/modification events |
| `archive-plan` | Session ends | Archives session plans with metadata |
| `pre-compact` | Before compaction | Captures state for post-compaction summary |
| `post-compact-summary` | After compaction | Extracts and saves compaction summaries |
| `notify-ready` | Claude responds | Desktop notification (macOS/Linux) with pending action count |
| `subagent-log` | Subagent completes | Triggers flywheel and learning exercise generation |
| `_meta-mode` | (helper) | Detects `.meta/` directory, routes session files accordingly |

All hooks read configuration from `ff.config.json` — no hardcoded platform assumptions.

### 14 Slash Commands

Commands are specialized subagent roles invoked with `/command-name`.

**TDD Pipeline:**

```
/architect  -->  /spec  -->  /test-gen  -->  /dev  -->  /review  -->  /test  -->  /docs
```

| Command | Role |
|---------|------|
| `/architect` | Design review, pattern selection, architecture fit analysis |
| `/spec` | Technical specification with test requirements and error handling matrix |
| `/test-gen` | TDD Red Phase — writes failing tests before implementation exists |
| `/dev` | TDD Green Phase — implements minimal code to pass tests |
| `/review` | Code review with security audit, TDD compliance, approval authority |
| `/test` | Runs full test suite, validates coverage, reports gaps |
| `/docs` | Documentation updates, ABOUTME audit, CLAUDE.md maintenance |

**Orchestration:**

| Command | Role |
|---------|------|
| `/orchestrate` | Sequential pipeline coordinator (new-feature, bug-fix, refactor, docs-only, security-audit) |
| `/team` | Parallel multi-agent workflows (competing investigators, multi-lens review) |

**Utilities:**

| Command | Role |
|---------|------|
| `/commit` | Git commit with pre-commit checks, conventional messages, todo tracking |
| `/push` | Git push with test verification and branch safety |
| `/context` | Context optimization — summarize, compress, load, analyze |
| `/learn` | Interactive learning exercises on autonomous work |
| `/wrap-up` | End-of-session documentation sweep |

### 9 Knowledge Skills

Skills are reference documents Claude loads on demand for specialized knowledge.

| Skill | What It Covers |
|-------|---------------|
| `context-fundamentals` | Context window management, what to load, what to drop |
| `context-compression` | Compression techniques for API responses, test output, error logs |
| `memory-systems` | Session, project, and workflow state tracking patterns |
| `multi-agent-patterns` | 6 coordination patterns for multi-agent workflows |
| `agent-teams-guide` | Parallel multi-agent team configurations and setup |
| `autonomous-guide` | Running headless/autonomous sessions with quality gates |
| `tdd-workflow` | Test-driven development cycle, pitfalls, and enforcement |
| `doc-flywheel` | Capture → Promote → Clear documentation workflow |
| `hooks-reference` | Complete reference for all 16 hooks |

## Quick Start

### Install into an existing project

```bash
git clone https://github.com/wittyreference/feature-factory.git /tmp/feature-factory
/tmp/feature-factory/scripts/init.sh ~/your-project
```

The init script will:
1. Detect your project's language (JavaScript, Python, Go, Rust, Java, Ruby, PHP)
2. Generate `ff.config.json` with your test/lint/coverage commands
3. Copy hooks, commands, skills, and settings into `.claude/`
4. Create `.meta/` for meta-development state
5. Update `.gitignore` with Feature Factory entries
6. Create or extend `CLAUDE.md`

### Preview before installing

```bash
/tmp/feature-factory/scripts/init.sh ~/your-project --dry-run
```

### Install with a platform overlay

```bash
/tmp/feature-factory/scripts/init.sh ~/your-project --overlay ~/twilio-overlay
```

## Configuration

Everything is driven by `ff.config.json` in your project root. The init script generates this with sensible defaults, but you should review and customize it.

### Project Settings

```json
{
  "project": {
    "name": "my-project",
    "language": "python",
    "sourceDirectories": ["src/", "lib/"]
  }
}
```

### Testing

```json
{
  "testing": {
    "command": "pytest",
    "coverageCommand": "pytest --cov",
    "coverageThreshold": 80,
    "testFilePatterns": ["**/*.test.*", "tests/**"]
  }
}
```

The `coverageThreshold` is enforced by quality gate hooks before deployment and on team task completion. Set it to match your project's standards.

### Linting

```json
{
  "linting": {
    "command": "ruff check .",
    "fixCommand": "ruff check --fix ."
  }
}
```

The `fixCommand` runs automatically after file writes. Leave empty to disable auto-fix.

### Deployment

```json
{
  "deployment": {
    "command": "npm run deploy",
    "preChecks": ["test", "lint", "coverage"]
  }
}
```

When the configured deploy command is detected, pre-deployment validation runs automatically: tests, coverage, and linting must all pass. Set `command` to `null` to disable.

### Credential Detection

```json
{
  "credentialPatterns": [
    {
      "pattern": "AKIA[0-9A-Z]{16}",
      "name": "AWS Access Key ID",
      "excludePattern": "(process\\.env|os\\.environ)"
    }
  ]
}
```

Add patterns for your platform's credential formats. The `excludePattern` prevents false positives when credentials are properly referenced via environment variables. Credential detection runs on every file write and on team task completion.

### File Headers (ABOUTME)

```json
{
  "fileHeaders": {
    "enabled": true,
    "pattern": "ABOUTME:",
    "requiredLines": 2,
    "fileExtensions": [".js", ".ts", ".py", ".go", ".rs"],
    "sourceOnly": true
  }
}
```

Every source file gets a grep-searchable 2-line header:

```python
# ABOUTME: Validates user registration requests against business rules.
# ABOUTME: Checks email uniqueness, password strength, and rate limits.
```

The hook blocks new files without headers and warns on existing files missing them.

### Documentation Flywheel

```json
{
  "docMappings": {
    "src/api/": "src/api/CLAUDE.md",
    "src/auth/": "docs/auth.md",
    ".claude/hooks/": "CLAUDE.md"
  }
}
```

Maps source directories to their documentation files. When code changes, the flywheel suggests which docs to update. Suggestions auto-clear when you stage the relevant doc files for commit.

## Key Systems

### The Documentation Flywheel

The flywheel watches what files you change and suggests documentation updates. It's not aspirational — it's structural.

```
Code changes  -->  Flywheel detects  -->  Suggests docs to update
                                              |
                                              v
                                    pending-actions.md
                                              |
                                              v
                           You address them  -->  Auto-cleared at commit
```

**Five sources of change detection:**
1. Uncommitted files (git status)
2. Recent commits (since session start)
3. Session-tracked files (from post-write hook)
4. Validation failure patterns (pattern database)
5. CLAUDE.md inventory drift (doc structure changes)

**Anti-spam:** 2-minute debounce, 24-hour staleness re-suggestion, recursive prevention (flywheel ignores its own output files).

### TDD Enforcement

The `/test-gen` → `/dev` pipeline doesn't just suggest TDD — it enforces it:

- `/test-gen` writes failing tests. If tests pass, it stops and says something is wrong.
- `/dev` checks for failing tests before writing any implementation. If no failing tests exist, it stops and tells you to run `/test-gen` first.
- Quality gate hooks block team task completion if implementation changes exist without corresponding test changes.
- Coverage threshold (default 80%) is enforced before deployment.

### Quality Gates

Quality gates are enforced by hooks — they run automatically, not by convention.

| Gate | When | Consequence |
|------|------|-------------|
| Credential safety | Every file write | Blocks write with exit code 2 |
| ABOUTME headers | New source files | Blocks write with exit code 2 |
| `--no-verify` | Git commit | Blocks command |
| Force push to main | Git push | Blocks command |
| Tests pass | Before deploy | Blocks deploy |
| Coverage threshold | Before deploy / task complete | Blocks deploy / task |
| Lint clean | Before deploy | Blocks deploy |
| Pending doc actions | Git commit | Blocks commit (override: `SKIP_PENDING_ACTIONS=true`) |

### Meta-Development Mode

When `.meta/` exists in your project root, you're developing the tooling itself — not shipping product. The system cleanly separates these concerns:

- **Production writes blocked** (unless `CLAUDE_ALLOW_PRODUCTION_WRITE=true`)
- Session files route to `.meta/` instead of `.claude/`
- Learnings, pending actions, plans, and logs all go to `.meta/`
- `.meta/` is gitignored — it never ships

Remove `.meta/` to return to standard mode.

### Learning Exercises

When Claude works autonomously (headless mode, `/orchestrate`, `/team`), you get clean artifacts but miss the decision-making. The learning system bridges that gap:

1. Hooks log file creation/modification events during autonomous work
2. `generate-learning-exercises.sh` creates structured exercises from those events
3. `/learn` presents exercises interactively — you predict, then compare to actual code
4. Max 2 exercises per session, decline suppresses further offers

Exercise types: **Prediction > Observation > Reflection**, **Generation > Comparison**, **Trace the Path**, **Debug This**.

## Platform Overlays

Feature Factory is platform-agnostic. Platform-specific tooling (credential patterns, commands, skills, deployment checks) is added via overlays.

An overlay is a directory that mirrors `.claude/` structure:

```
my-overlay/
  commands/         # Additional or replacement slash commands
  skills/           # Platform-specific knowledge docs
  references/       # API references, CLI guides
  ff.config.overlay.json    # Config to merge with ff.config.json
  claude-md-section.md      # Content to append to CLAUDE.md
```

Install with:

```bash
/path/to/feature-factory/scripts/init.sh . --overlay /path/to/my-overlay
```

The overlay's config is deep-merged with `ff.config.json`. Commands and skills with the same filename replace the generic versions; new ones are added alongside.

## Project Structure

```
your-project/
  .claude/
    hooks/           # 16 event-driven hooks (auto-fire on Claude Code events)
    commands/        # 14 slash commands (/architect, /dev, /test-gen, etc.)
    skills/          # 9 knowledge documents (loaded on demand)
    references/      # Documentation maps
    settings.json    # Hook registrations and environment config
  .meta/             # Meta-development state (gitignored)
    learnings.md     # Session discoveries
    pending-actions.md  # Flywheel doc suggestions
    todo.md          # Development roadmap
    plans/           # Archived session plans
    logs/            # Session event logs
    learning/        # Exercise infrastructure
  ff.config.json     # Central configuration (edit this)
  CLAUDE.md          # Root documentation (auto-loaded by Claude Code)
  DESIGN_DECISIONS.md  # Architectural decision records
```

## Testing

Feature Factory tests itself:

```bash
# Run all tests
npm test

# Run leakage check (verifies no platform-specific references)
npm run test:leakage

# Run hook functional tests (27 tests)
npm run test:hooks
```

The leakage test runs 11 checks ensuring zero platform-specific coupling — no hardcoded credential patterns, no platform API references, no vendor-specific paths.

## Prerequisites

- **git** (required) — hooks use git for change detection
- **jq** (required) — hooks read `ff.config.json` via jq
- **Claude Code** — this toolkit is built for Claude Code's hook system

## Origin

These patterns were developed over 770+ sessions building a production Twilio prototyping platform with Claude Code. The documentation flywheel, TDD enforcement, quality gates, meta-mode isolation, and learning exercises all emerged from real needs — each one traces back to a specific bug, oversight, or "we should have caught that" moment. We extracted the platform-agnostic infrastructure into this standalone toolkit so any project can benefit from the same discipline.

## License

MIT
