---
paths:
  - ".claude/commands/**"
  - ".claude/skills/**"
---

# Development Tools Architecture

## How It Works

```text
┌─────────────────────────────────────────────────────────────────┐
│  Claude Code (Interactive Orchestrator)                         │
│  ───────────────────────────────────────────────────────────────│
│  Single session │ Agent Teams │ Plan mode → Approval            │
└─────────────────────────────────────────────────────────────────┘
                              │
                    invokes as needed
                              │
    ┌───────────────┬─────────┼─────────┐
    │               │         │         │
    ▼               ▼         ▼         ▼
┌─────────────┐ ┌─────────┐ ┌─────────────┐
│ Slash Cmds  │ │  Agent  │ │ MCP Server  │
│ ────────────│ │  Teams  │ │ ────────────│
│ /architect  │ │ ────────│ │ External    │
│ /spec       │ │ /team   │ │ APIs as     │
│ /test-gen   │ │ Parallel│ │ tools       │
│ /dev        │ │ multi-  │ │             │
│ /review     │ │ agent   │ │             │
│ /docs       │ │ work    │ │             │
└─────────────┘ └─────────┘ └─────────────┘
```

## Key Principles

1. **Slash commands** are specialized agent roles with focused prompts
2. **Agent Teams** coordinate multiple Claude Code instances for parallel work
3. **MCP tools** provide structured API access without shell invocation
4. **Plan mode** ensures user approval before significant changes
5. **Hooks** enforce quality gates (TDD, linting, credential safety) automatically

## When to Use Each

| Need | Use |
|------|-----|
| Sequential development pipeline | `/orchestrate` |
| Parallel investigation or review | `/team` |
| Specific phase of work | Individual slash command |
| Query external data | MCP tools |
| One-off operations | CLI directly |
