# Development Workflows

This document describes the available workflow patterns for developing features using Claude Code subagents and agent teams.

## Available Subagents

| Command | Role | Description |
|---------|------|-------------|
| `/orchestrate` | Workflow Coordinator | Runs full development pipelines automatically |
| `/architect` | Architect | Design review, pattern selection, unknowns identification |
| `/prototype` | Prototyper | Quick spike to test unknowns -- no tests, produces learnings |
| `/spec` | Specification Writer | Creates detailed technical specifications |
| `/test-gen` | Test Generator | TDD Red Phase - writes failing tests first |
| `/dev` | Developer | TDD Green Phase - implements to pass tests |
| `/review` | Senior Developer | Code review, security audit, approval authority |
| `/test` | Test Runner | Executes and validates test suites |
| `/docs` | Technical Writer | Documentation updates and maintenance |

## Workflow Patterns

### New Feature Pipeline

Full development pipeline for building new functionality:

```text
/architect ──► /prototype (if unknowns) ──► /spec ──► /test-gen ──► /dev ──► /review ──► /test ──► /docs
```

**Orchestrated**: `/orchestrate new-feature [description]`

**Manual execution**:

1. `/architect [feature]` - Get architecture review, identify unknowns
2. `/prototype [unknowns]` - Quick spike to test unfamiliar APIs *(skip if no unknowns)*
3. `/spec [feature]` - Create detailed technical specification
4. `/test-gen [feature]` - Generate failing tests (TDD Red)
5. `/dev [feature]` - Implement to pass tests (TDD Green)
6. `/review` - Code review and security audit
7. `/test` - Run full test suite
8. `/docs` - Update documentation

### Bug Fix Pipeline

Quick fix pipeline for resolving issues:

```text
/architect ──► /test-gen ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate bug-fix [issue]`

**Manual execution**:

1. `/architect [diagnosis]` - Determine fix approach
2. `/test-gen [regression]` - Write regression tests
3. `/dev [fix]` - Implement the fix
4. `/review` - Validate the fix
5. `/test` - Verify all tests pass

### Refactor Pipeline

Improve code structure without changing behavior:

```text
/test ──► /architect ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate refactor [target]`

**Manual execution**:

1. `/test` - Verify existing tests pass (baseline)
2. `/architect [refactor plan]` - Design the refactoring approach
3. `/dev [refactor]` - Implement changes
4. `/review` - Validate changes
5. `/test` - Confirm behavior unchanged

### Documentation Only

Update documentation without code changes:

```text
/docs
```

**Orchestrated**: `/orchestrate docs-only [scope]`

**Manual execution**:

1. `/docs [scope]` - Update specified documentation

### Security Audit

Review code for security issues:

```text
/review ──► /dev ──► /test
```

**Orchestrated**: `/orchestrate security-audit [scope]`

**Manual execution**:

1. `/review security [scope]` - Security-focused code review
2. `/dev [fixes]` - Implement security fixes (if needed)
3. `/test` - Validate fixes

## Agent Team Workflows

For tasks that benefit from parallel work or inter-agent discussion, use `/team` instead of `/orchestrate`. Agent teams spawn multiple Claude Code instances that communicate via messaging and a shared task list.

### When to Use Teams vs Subagents

| Criteria | Use Subagents (`/orchestrate`) | Use Teams (`/team`) |
|----------|-------------------------------|---------------------|
| Task structure | Sequential, clear phases | Parallel or adversarial |
| Communication | Results flow one direction | Agents discuss findings |
| Context needs | Shared context is fine | Each agent needs fresh context |
| Token budget | Tight | Flexible (2-3x more) |
| Best for | Routine features | Bug debugging, code review, complex features |

### Team: New Feature (Parallel Review)

```text
Phase 1 (Sequential): architect → spec → test-gen → dev
Phase 2 (Parallel):   qa ──┬── review
Phase 3 (Sequential): docs
```

Run with: `/team new-feature [description]`

QA and review teammates work in parallel after implementation, each with a fresh context window. Both must pass quality gates before docs teammate starts.

### Team: Bug Fix (Competing Hypotheses)

```text
Phase 1 (Parallel): investigator-1 ──┬── investigator-2 ──┬── investigator-3
                    (code path)       │   (logs/state)     │   (config/env)
Phase 2: Lead synthesizes strongest hypothesis
Phase 3 (Sequential): test-gen → dev → review
```

Run with: `/team bug-fix [issue]`

Three investigators work in parallel, messaging each other to challenge hypotheses. Lead picks the strongest root cause analysis.

### Team: Code Review (Multi-Lens)

```text
Phase 1 (Parallel): security ──┬── performance ──┬── testing
Phase 2: Cross-challenge (each reads others' findings)
Phase 3: Lead compiles unified review
```

Run with: `/team code-review [scope]`

Three reviewers with different focus areas. After initial review, each reads others' findings and adds counter-points or agreement.

### Team: Refactor (Parallel Analysis)

```text
Phase 1 (Parallel): baseline-qa ──┬── architect
Phase 2 (Sequential): dev (tests must stay green)
Phase 3 (Parallel): verify-qa ──┬── reviewer
```

Run with: `/team refactor [target]`

Baseline QA and architect work in parallel to establish metrics and plan. After implementation, verification and review run in parallel.

### Team: Validation (Parallel Domain Coverage)

```text
Phase 1 (Parallel): validator-1 ──┬── validator-2 ──┬── validator-3
                    (domain A)     │   (domain B)    │   (domain C)
Phase 2 (Sequential): Lead aggregates results into unified validation report
```

Run with: `/team validation [scope]`

Multiple validators run simultaneously, each focused on one domain or component. Lead synthesizes findings into a unified pass/fail report. Use after deployments or workflow completions to verify multiple areas in parallel.

## Standalone vs Orchestrated vs Team-Based

All subagents work independently. Choose the approach that fits your workflow:

### Orchestrated Mode

Use `/orchestrate` when:

- Building a complete new feature with sequential phases
- Following a standard workflow pattern
- Want automated sequencing and handoffs
- Working on a well-defined task

### Team-Based Mode

Use `/team` when:

- Agents need to discuss or challenge each other's findings
- Parallel work would save time (e.g., qa + review simultaneously)
- Task benefits from competing hypotheses (bug debugging)
- Each agent needs a fresh context window (prevents bloat)

### Standalone Mode

Run individual subagents when:

- Working on a specific phase only
- Need more control over the process
- Task doesn't fit standard patterns
- Iterating on a particular aspect

## TDD Enforcement

This project strictly follows Test-Driven Development:

1. **Red Phase** (`/test-gen`): Write failing tests first
2. **Green Phase** (`/dev`): Write minimal code to pass tests
3. **Refactor**: Improve code while keeping tests green

The `/dev` subagent will verify that failing tests exist before implementing. If no tests exist, it will suggest running `/test-gen` first.

## Handoff Protocol

Each subagent suggests the next logical step:

| After | Suggests |
|-------|----------|
| `/architect` | `/prototype` (if unknowns) or `/spec` (if no unknowns) |
| `/prototype` | `/spec` for detailed specification |
| `/spec` | `/test-gen` for test generation |
| `/test-gen` | `/dev` for implementation |
| `/dev` | `/review` for code review |
| `/review` (APPROVED) | `/test` for final validation |
| `/review` (NEEDS_CHANGES) | `/dev` for fixes |
| `/test` | `/docs` for documentation |
| `/deploy` | `/team validation` for post-deploy verification |

## Best Practices

1. **Always start with `/architect`** for new features to ensure proper design
2. **Prototype unknowns first** -- if the architect identifies unfamiliar APIs or ambiguous behavior, spike them before writing a spec
3. **Use `/spec`** to clarify requirements before writing code
4. **Never skip `/test-gen`** - tests must exist before implementation
5. **Run `/review`** before merging any significant changes
6. **Keep `/docs`** updated as features evolve
7. **Use `/team`** for bug debugging (competing hypotheses find root causes faster)
8. **Use `/team`** for code review (multi-lens parallel review catches more issues)
9. **Avoid teams for simple sequential tasks** (overhead exceeds benefit)
