# Development Workflows

This document describes the available workflow patterns for developing features using Claude Code subagents.

## Available Subagents

| Command | Role | Description |
|---------|------|-------------|
| `/orchestrate` | Workflow Coordinator | Runs full development pipelines automatically |
| `/architect` | Architect | Design review, pattern selection |
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
/architect ──► /spec ──► /test-gen ──► /dev ──► /review ──► /test ──► /docs
```

**Orchestrated**: `/orchestrate new-feature [description]`

**Manual execution**:

1. `/architect [feature]` - Get architecture review and pattern recommendations
2. `/spec [feature]` - Create detailed technical specification
3. `/test-gen [feature]` - Generate failing tests (TDD Red)
4. `/dev [feature]` - Implement to pass tests (TDD Green)
5. `/review` - Code review and security audit
6. `/test` - Run full test suite
7. `/docs` - Update documentation

### Bug Fix Pipeline

```text
/architect ──► /test-gen ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate bug-fix [issue]`

### Refactor Pipeline

```text
/test ──► /architect ──► /dev ──► /review ──► /test
```

**Orchestrated**: `/orchestrate refactor [target]`

### Documentation Only

```text
/docs
```

**Orchestrated**: `/orchestrate docs-only [scope]`

### Security Audit

```text
/review ──► /dev ──► /test
```

**Orchestrated**: `/orchestrate security-audit [scope]`

## Standalone vs Orchestrated

### Orchestrated Mode

Use `/orchestrate` when:
- Building a complete new feature with sequential phases
- Following a standard workflow pattern
- Want automated sequencing and handoffs

### Standalone Mode

Run individual subagents when:
- Working on a specific phase only
- Need more control over the process
- Task doesn't fit standard patterns
- Iterating on a particular aspect

## TDD Enforcement

1. **Red Phase** (`/test-gen`): Write failing tests first
2. **Green Phase** (`/dev`): Write minimal code to pass tests
3. **Refactor**: Improve code while keeping tests green

The `/dev` subagent will verify that failing tests exist before implementing.

## Handoff Protocol

| After | Suggests |
|-------|----------|
| `/architect` | `/spec` for detailed specification |
| `/spec` | `/test-gen` for test generation |
| `/test-gen` | `/dev` for implementation |
| `/dev` | `/review` for code review |
| `/review` (APPROVED) | `/test` for final validation |
| `/review` (NEEDS_CHANGES) | `/dev` for fixes |
| `/test` | `/docs` for documentation |

## Best Practices

1. **Always start with `/architect`** for new features
2. **Use `/spec`** to clarify requirements before writing code
3. **Never skip `/test-gen`** - tests must exist before implementation
4. **Run `/review`** before merging any significant changes
5. **Keep `/docs`** updated as features evolve
