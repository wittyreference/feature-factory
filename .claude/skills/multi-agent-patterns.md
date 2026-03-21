---
name: multi-agent-patterns
description: Agent orchestration and coordination patterns. Use when designing multi-agent workflows, choosing between parallel/sequential/hierarchical patterns, or coordinating subagents.
---

# Multi-Agent Patterns

This skill describes orchestration and coordination patterns for development workflows.

## Pattern Overview

| Pattern | Best For | Use Case |
|---------|----------|----------|
| Orchestrator | Sequential flows | Feature development pipeline |
| Agent Teams | Parallel + adversarial | Bug debugging, code review, parallel QA |
| Peer-to-Peer | Parallel work | Debugging + fixing simultaneously |
| Hierarchical | Complex features | Multi-component solutions |
| Evaluator | Quality gates | Code review with standards |
| TDD Pipeline | Code quality | Red -> Green -> Refactor |

## Cross-Cutting Concerns

### Human Approval Gates

The project operates in "Highly Supervised" autonomy mode. Human approval is required at key checkpoints:

```
architect -> [APPROVAL] -> spec -> [APPROVAL] -> test-gen -> dev -> qa -> review -> [APPROVAL] -> docs
```

Approval gates pause execution until human confirms:
- Architecture decisions are sound
- Specifications are correct
- Code is ready for merge

### TDD Enforcement

All development workflows enforce Test-Driven Development via pre-phase hooks:

1. **test-gen** must create tests that **fail** initially (Red phase)
2. **tdd-enforcement hook** runs BEFORE dev phase and verifies:
   - Tests exist (`testsCreated > 0`)
   - Tests are FAILING
3. **dev** is blocked with `TDD VIOLATION` if tests pass or don't exist
4. **dev** implements minimal code to make tests pass (Green phase)
5. **review** validates TDD was followed

```typescript
// Pre-phase hooks in workflow definition
{
  agent: 'dev',
  name: 'TDD Green Phase',
  prePhaseHooks: ['tdd-enforcement'],  // Blocks if tests don't fail
}
```

See `.claude/skills/tdd-workflow.md` for detailed TDD patterns.

## Orchestrator Pattern (Default)

A central coordinator manages the workflow, invoking specialists in sequence.

### Structure

```
                    +-------------+
                    |  Claude Code |
                    |  (sequencer) |
                    +------+------+
                           |
     +---------+-----------+-----------+---------+
     v         v           v           v         v
+---------+ +-----+ +----------+ +-----+ +--------+
|/architect| |/spec| |/test-gen | |/dev | |/review |
+---------+ +-----+ +----------+ +-----+ +--------+
```

### When to Use

- New feature development (sequential phases)
- Bug fixes (diagnose -> test -> fix -> verify)
- Refactoring (test -> change -> test)

### Example: New API Feature

```
/architect "Add user registration"

Phase 1: /architect
  -> Design: src/handlers/register.js
  -> Pattern: Validate -> Process -> Respond

Phase 2: /spec
  -> Input: email, password, name
  -> Output: User object with auth token

Phase 3: /test-gen
  -> Unit tests for input validation
  -> Integration test for registration flow

Phase 4: /dev
  -> Implement register.js
  -> Make tests pass

Phase 5: /review
  -> Security: Input sanitization check
  -> Patterns: Matches project conventions

Phase 6: /test
  -> All tests passing
```

### Handoff Protocol

Each agent passes structured context to the next:

```markdown
## Handoff: /architect -> /spec

Files identified:
- src/handlers/register.js (create)
- __tests__/unit/handlers/register.test.js (create)

Architecture decisions:
- Validate input with Joi schema
- Hash passwords with bcrypt before storage
- Return JWT token on successful registration

Ready for: Detailed specification
```

## Peer-to-Peer Pattern

Agents work in parallel on related but independent tasks. For true parallel coordination with inter-agent messaging, see [Agent Teams Pattern](#agent-teams-pattern) above.

### Structure

```
        +-------------+
        |    User     |
        +------+------+
               |
       +-------+-------+
       v               v
  +---------+    +---------+
  | Agent A |<-->| Agent B |
  +---------+    +---------+
```

### When to Use

- Debugging (analyze logs while reviewing code)
- Multi-file changes (update function + tests simultaneously)
- Documentation (code + docs in parallel)

### Example: Debugging API Failure

```
Parallel agents:

Agent A: Log analysis
  -> Analyzing error logs for 500 errors
  -> Found: Null pointer on missing request body field
  -> Confidence: HIGH

Agent B: Code review
  -> Reading create-user.js
  -> Found: No validation on 'email' parameter
  -> Confirms log analysis finding

Sync point:
  -> Root cause: Missing input validation
  -> Fix: Add null check and email format validation
```

### Coordination Mechanism

Agents share findings through explicit sync points:

```markdown
## Sync: Debug Analysis Complete

Agent A findings:
- 500 error: Cannot read property 'email' of undefined
- 5 failures in last hour
- All from same endpoint

Agent B findings:
- No input validation in create-user handler
- Request body not checked before access

Combined insight:
- Need input validation before processing
- Add test for missing/empty request body
```

## Hierarchical Pattern

A lead agent delegates to sub-agents, which may further delegate.

### Structure

```
              +--------------+
              |  Lead Agent  |
              |  /architect  |
              +-------+------+
                      |
        +-------------+-------------+
        v             v             v
   +---------+   +---------+   +---------+
   |  API    |   |  Auth   |   | Storage |
   |  Team   |   |  Team   |   |  Team   |
   +----+----+   +----+----+   +----+----+
        |             |             |
     +--+--+       +--+--+       +--+--+
     v     v       v     v       v     v
   /spec  /dev   /spec  /dev   /spec  /dev
```

### When to Use

- Multi-component features (API + auth + storage)
- Large refactoring (multiple subsystems)
- Complex workflows with nested steps

### Example: Multi-Component Notification System

```
Lead: /architect "Build notification system with email, SMS, and push"

Delegation:
+-- Email Team
|   +-- /spec email notification
|   +-- /dev src/notifications/email.js
|
+-- SMS Team
|   +-- /spec SMS notification
|   +-- /dev src/notifications/sms.js
|
+-- Orchestration Team
    +-- /spec fallback logic (email -> SMS -> push)
    +-- /dev src/notifications/orchestrator.js

Rollup:
- Each team reports completion + test status
- Lead verifies integration
- Final /review of complete system
```

### Supervision Protocol

Lead agent maintains oversight:

```markdown
## Status: Multi-Component Notification

Email Team: COMPLETE
- email.js implemented
- Tests passing

SMS Team: IN_PROGRESS
- sms.js implemented
- Tests: 1 failing (rate limit handling)

Push Team: BLOCKED
- Waiting on SMS team completion

Lead action: Assist SMS team with rate limit test
```

## Evaluator Pattern

An evaluator agent assesses work quality against standards.

### Structure

```
+---------+     +-----------+     +----------+
|Producer |---->| Evaluator |---->| Decision |
|  /dev   |     |  /review  |     |PASS/FAIL |
+---------+     +-----------+     +----------+
                      |
                      v
               +------------+
               | Feedback   |
               | Loop       |
               +------------+
```

### When to Use

- Code review gates
- Security audits
- TDD verification (tests must fail first)

### Example: Code Review Gate

```
/review src/handlers/create-user.js

Evaluation criteria (from CLAUDE.md):

[ ] ABOUTME comments present
  -> Line 1-2: Descriptive ABOUTME

[ ] No hardcoded credentials
  -> Uses environment variables for secrets

[ ] Error handling present
  -> Validates input parameters
  x  Missing try/catch around database call

[ ] Tests exist and pass
  -> 4 unit tests passing

Verdict: NEEDS_CHANGES
Reason: Add try/catch for database operations
```

## Agent Teams Pattern

Real parallel coordination with inter-agent messaging. Unlike subagents (which share the parent's context and can only report back), teammates have their own context windows and communicate directly with each other.

### Structure

```
              +--------------+
              |   Lead Agent |
              |  (delegate   |
              |    mode)     |
              +-------+------+
                      | shared task list
        +-------------+-------------+
        v             v             v
   +---------+  +---------+  +---------+
   |Teammate |<>|Teammate |<>|Teammate |
   |    A    |  |    B    |  |    C    |
   +---------+  +---------+  +---------+
        <-- direct messaging -->
```

### When to Use

- Bug debugging with competing hypotheses (3 investigators challenge each other)
- Multi-lens code review (security + performance + tests in parallel)
- Parallel QA + review after implementation
- Cross-layer changes (handlers + services + config)

### Comparison: Subagents vs Agent Teams vs Feature Factory

| Aspect | Subagents | Agent Teams | Feature Factory |
|--------|-----------|-------------|-----------------|
| **Context** | Shared with parent | Own window per teammate | Own SDK session |
| **Communication** | Return results to caller | Message each other + shared tasks | Phase handoffs |
| **Parallelism** | Sequential | Parallel | Sequential |
| **Token cost** | Lowest | ~2-3x | Medium |
| **Resumable** | Yes | No | Yes |
| **Best for** | Sequential workflows | Adversarial/parallel work | CI/CD automation |

### Example: Bug Fix with Competing Hypotheses

```
/team bug-fix "API endpoint returning 500 for empty body"

Parallel investigators:

Teammate "code-tracer":
  -> Reading create-user.js
  -> Found: No body validation, crashes on undefined
  -> Confidence: HIGH

Teammate "log-analyst":
  -> Checking error logs for 500 responses
  -> Found: 500 errors from /api/users endpoint
  -> Confirms code-tracer's finding

Teammate "config-checker":
  -> Checking middleware config, env vars
  -> All correct -- rules out configuration issue
  -> Supports code-level root cause

Lead synthesis:
  -> Root cause: Missing body validation
  -> Fix: Add null check before processing
  -> Regression test: Empty body should return 400, not 500
```

### Quality Gates

Teammates are subject to `TeammateIdle` and `TaskCompleted` hooks:
- test-gen tasks: Tests must exist AND fail
- dev tasks: Tests must pass + lint clean
- qa tasks: Coverage >= 80%
- All tasks: No hardcoded credentials

## Pattern Selection Guide

```
Is work sequential with clear phases?
+-- Yes -> Sequential Pipeline
|         Start with /architect, follow phase sequence
|
+-- No -> Do agents need to discuss findings?
         +-- Yes -> Agent Teams Pattern
         |         Use /team command
         |
         +-- No -> Can tasks run independently?
                  +-- Yes -> Peer-to-Peer Pattern
                  |         Run multiple commands in parallel
                  |
                  +-- No -> Is there natural hierarchy?
                           +-- Yes -> Hierarchical Pattern
                           |         Lead agent delegates to teams
                           |
                           +-- No -> Evaluator Pattern
                                     Quality gate with feedback loop
```

## Architecture Considerations

### Sequential Pipelines = Orchestrator

Many development workflows naturally follow orchestrator pattern:

```
Request -> Validate -> Process -> Store -> Respond
     |          |          |         |         |
     v          v          v         v         v
  Handler 1  Handler 2  Handler 3  Handler 4  Handler 5
```

Each handler is a function that passes control to the next in the pipeline.

### Real-Time Features = Peer Pattern

WebSocket and real-time features benefit from peer coordination:

```
+------------------+     +------------------+
|  HTTP Handler    |<--->|  WebSocket Server|
|  (REST API)      |     |  (real-time)     |
+------------------+     +------------------+
         |                       |
         +-----------+-----------+
                     v
              +-------------+
              | Shared State|
              |  (context)  |
              +-------------+
```

### Multi-Component = Hierarchical

Features spanning multiple layers need hierarchical coordination:

```
User Management System
+-- Layer Selection (Lead)
|   +-- API: REST endpoints
|   +-- Auth: Token management
|   +-- Storage: Database operations
+-- Integration (Shared)
```
