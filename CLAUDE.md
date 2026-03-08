# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project uses **Feature Factory** — a self-documenting, self-healing, TDD-enforcing development toolkit for Claude Code. It provides hooks, commands, skills, and workflows that enforce quality gates and maintain documentation automatically.

## Meta-Development Mode

When `.meta/` exists at the project root, this is a meta-development environment (gitignored, never ships). You are developing the tooling itself, not using it as a shipped product.

**File routing in meta-development mode:** Session-specific files live under `.meta/` instead of at root or `.claude/`:

- **Todo / roadmap**: `.meta/todo.md` in meta-development, `todo.md` otherwise
- **Session learnings**: `.meta/learnings.md` in meta-development, `.claude/learnings.md` otherwise
- **Pending actions**: `.meta/pending-actions.md` in meta-development, `.claude/pending-actions.md` otherwise
- **Archived plans**: `.meta/plans/` in meta-development, `.claude/archive/plans/` otherwise

The hooks in `.claude/hooks/` auto-detect the environment. Claude must also follow this routing — when the user says "todo" or "learnings", use the meta-development paths if `.meta/` exists.

**NEVER rename or move `.meta/` to bypass hook enforcement.** If a hook is blocking legitimate work, fix the hook in a separate session.

## Documentation Navigator

| Looking for... | Location |
|----------------|----------|
| Project-wide standards | This file (CLAUDE.md) |
| Architectural decisions | [DESIGN_DECISIONS.md](/DESIGN_DECISIONS.md) |
| Hooks reference | `.claude/skills/hooks-reference.md` (load on demand) |
| Autonomous mode | `.claude/skills/autonomous-guide.md` (load on demand) |
| Agent teams details | `.claude/skills/agent-teams-guide.md` (load on demand) |
| Doc flywheel | `.claude/skills/doc-flywheel.md` (load on demand) |
| Context Hub (external APIs) | `.claude/skills/context-hub.md` (load on demand) |
| Learning exercises | `.claude/commands/learn.md`, `.meta/learning/` |
| Implementation progress | Todo file (see [Meta-Development Mode](#meta-development-mode)) |
| Session learnings | Learnings file (see [Meta-Development Mode](#meta-development-mode)) |

## Your Role as Primary Agent
- **Architecture & Planning**: Lead on system design and specification creation
- **Test-Driven Development**: Primary responsibility for comprehensive test coverage
- **Code Review**: Final validation of complex logic and architectural decisions
- **Documentation**: Maintain and update technical documentation

## Development Pipeline

For any task that creates new source files or implements significant new features, you MUST use the development pipeline — either via `/orchestrate` or by running the phases sequentially:

1. `/architect` — Design review and pattern selection
2. `/spec` — Detailed technical specification
3. `/test-gen` — Write failing tests (TDD Red Phase)
4. `/dev` — Implement to pass tests (TDD Green Phase)
5. `/review` — Code review and security audit
6. `/docs` — Documentation updates

**When to use the pipeline:**
- Creating new source files in tracked directories
- Adding a significant new feature or capability
- Implementing anything that touches multiple modules

**When the pipeline is NOT needed:**
- Bug fixes to existing files
- Documentation updates
- Configuration changes
- Single-line tweaks or refactors within an existing file

The pre-write hook enforces this — new source files without corresponding tests will be blocked.

## Documentation Protocol

This project uses a **doc-first approach**: Check → Act → Record.

### Before Code Changes

Read the relevant `CLAUDE.md` file for the domain you're modifying.
- **External APIs**: If code calls non-project APIs, check context-hub: `chub search "<api>"`. See `.claude/skills/context-hub.md` for workflow.

### Discovery Capture

When you learn something unexpected, add it to the learnings file **IMMEDIATELY** (see [Meta-Development Mode](#meta-development-mode) for path). Don't wait until the end of a task — capture inline as you discover.

### Before Committing

1. Check the pending actions file for doc update suggestions (see [Meta-Development Mode](#meta-development-mode) for path)
2. Address suggestions or consciously defer them
3. Verify you recorded any learnings from this session

For the full capture-promote-clear documentation workflow, see the `doc-flywheel` skill.

# Interaction

- When you first work with a new user, ask for their preferred name and update this file.
- **Preferred name: [Your name here]**

## Working Together

- We are collaborators working together on technical problems.
- Communication should be direct, professional, and collegial.
- Mutual respect: neither party is infallible, and we learn from each other.
- It's encouraged to push back with evidence when you disagree.
- Ask questions when something is unclear rather than making assumptions.

## Communication style

- Get straight to the point. Skip the preamble phrases like "Great idea!", "Good question!", "Absolutely!", etc.
- Be direct without being cold. Friendly and professional, not effusive.
- You don't need to validate or congratulate me. Just engage with the content.
- It's fine to disagree, express uncertainty, or say "I don't know" - that's more useful than false confidence or hollow agreement.
- Keep responses concise. If something can be said in fewer words, do that.
- Save enthusiasm for when something is genuinely interesting or well-done, so it means something when you express it.

# Writing code

- CRITICAL: NEVER USE --no-verify WHEN COMMITTING CODE
- We prefer simple, clean, maintainable solutions over clever or complex ones, even if the latter are more concise or performant. Readability and maintainability are primary concerns.
- Make the smallest reasonable changes to get to the desired outcome. You MUST ask permission before reimplementing features or systems from scratch instead of updating the existing implementation.
- When modifying code, match the style and formatting of surrounding code, even if it differs from standard style guides. Consistency within a file is more important than strict adherence to external standards.
- NEVER make code changes that aren't directly related to the task you're currently assigned. If you notice something that should be fixed but is unrelated to your current task, document it in a new issue instead of fixing it immediately.
- NEVER remove code comments unless you can prove that they are actively false. Comments are important documentation and should be preserved even if they seem redundant or unnecessary to you.
- All code files should start with a brief 2 line comment explaining what the file does. Each line of the comment should start with the string "ABOUTME: " commented out in whatever the file's comment syntax is to make it easy to grep for.
- When writing comments, avoid referring to temporal context about refactors or recent changes. Comments should be evergreen and describe the code as it is, not how it evolved or was recently changed.
- NEVER implement a mock mode for testing or for any purpose. We always use real data and real APIs, never mock implementations.
- When you are trying to fix a bug or compilation error or any other issue, YOU MUST NEVER throw away the old implementation and rewrite without explicit permission from the user.
- NEVER name things as 'improved' or 'new' or 'enhanced', etc. Code naming should be evergreen.
- Commit your work regularly using git. Commit whenever you complete an atomic unit of functionality. Each commit should represent a coherent, working state.

# Getting help

- ALWAYS ask for clarification rather than making assumptions.
- If you're having trouble with something, it's ok to stop and ask for help.

# Debugging

- Form a hypothesis and verify it with actual data BEFORE attempting fixes. Do not shotgun-debug by trying random changes.
- Do not switch approaches without confirming with the user first. The current approach usually exists for a reason.
- When a multi-step validation or implementation plan exists, NEVER silently skip steps. Report completion status for every step.
- If authentication or credentials expire mid-session, surface it to the user immediately.

## When Blocked by a Hook

When a pre-write or pre-bash hook blocks your action, **do not guess at workarounds**. Follow this protocol:

1. **Check `settings.local.json` first.** The permissions list is a record of previously-approved workflows. Search it for the pattern you need — the answer is almost always already there.
2. **Use the established bypass.** For meta-mode write blocks, prepend the env var to a Bash command:
   ```bash
   CLAUDE_ALLOW_PRODUCTION_WRITE=true cat > src/path/file.js << 'EOF'
   ...
   EOF
   ```
3. **Do NOT** edit hooks, modify `settings.json` env blocks, add paths to allowed lists, or ask the user to set environment variables. These are all wrong.
4. If `settings.local.json` has no prior art and you genuinely don't know the bypass, **ask the user** instead of trying multiple approaches.

# Session discipline

- Prioritize the pipeline over ad-hoc implementation. For tasks that create new source files, always invoke `/orchestrate` or run pipeline phases sequentially. Ad-hoc coding (skipping architect/spec) is only appropriate for bug fixes and small edits to existing files.
- Do not convert lazy/conditional imports to static imports without verifying the conditional logic still works. Conditional loading exists for a reason (optional dependencies, environment-specific loading).
- Run the full relevant test suite before presenting work as complete. A passing subset is not sufficient — regressions in unrelated tests still need to be caught.
- After modifying TypeScript files, run `tsc --noEmit` in the relevant package to verify compilation before committing.

# Testing

- Tests MUST cover the functionality being implemented.
- NEVER ignore the output of the system or the tests - Logs and messages often contain CRITICAL information.
- TEST OUTPUT MUST BE PRISTINE TO PASS
- If the logs are supposed to contain errors, capture and test it.
- NO EXCEPTIONS POLICY: Under no circumstances should you mark any test type as "not applicable". Every project MUST have unit tests, integration tests, AND end-to-end tests. If you believe a test type doesn't apply, you need the human to say exactly "I AUTHORIZE YOU TO SKIP WRITING TESTS THIS TIME"
- We practice TDD: write tests first, make them pass, refactor. The `/dev` subagent verifies failing tests exist before implementing.

## Build and Development Commands

Configure your project's commands in `ff.config.json`. The hooks will use these for validation:

```json
{
  "testing": {
    "command": "<your test command>",
    "coverageCommand": "<your coverage command>",
    "coverageThreshold": 80
  },
  "linting": {
    "command": "<your lint command>",
    "fixCommand": "<your lint fix command>"
  },
  "deployment": {
    "command": "<your deploy command>"
  }
}
```

## Custom Slash Commands

### Workflow Commands

| Command | Description |
|---------|-------------|
| `/orchestrate [workflow] [task]` | Workflow coordinator - runs full development pipelines |
| `/team [workflow] [task]` | Agent team coordinator - parallel multi-agent workflows |

### Development Subagents

| Command | Description |
|---------|-------------|
| `/architect [topic]` | Architect - design review, pattern selection, CLAUDE.md maintenance |
| `/spec [feature]` | Specification writer - creates detailed technical specifications |
| `/test-gen [feature]` | Test generator - TDD Red Phase, writes failing tests first |
| `/dev [task]` | Developer - TDD Green Phase, implements to pass tests |
| `/review [target]` | Senior developer - code review, security audit, approval authority |
| `/test [scope]` | Test runner - executes and validates test suites |
| `/docs [scope]` | Technical writer - documentation updates and maintenance |

### Utility Commands

| Command | Description |
|---------|-------------|
| `/commit [scope]` | Git commit with pre-commit checks, conventional messages, todo tracking |
| `/push` | Push to remote with test verification and branch tracking |
| `/context [action]` | Context optimization - summarize, load, or analyze context |
| `/wrap-up [scope]` | End-of-session doc updates — learnings, CLAUDE.md, todo, pending actions |
| `/learn [action]` | Interactive learning exercises on autonomous work |

## Platform-Specific Extensions

If this project uses a platform overlay (e.g., cloud platforms, API providers), platform-specific patterns, commands, and skills will be available in `.claude/skills/platform-patterns.md` and as additional slash commands. Check the documentation navigator above for platform-specific entries.
