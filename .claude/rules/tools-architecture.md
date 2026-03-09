---
paths:
  - "agents/**"
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

         OR (for headless automation)

┌─────────────────────────────────────────────────────────────────┐
│  Feature Factory (Claude Agent SDK)                             │
│  ───────────────────────────────────────────────────────────────│
│  npx feature-factory new-feature "task"                         │
│  CI/CD pipelines, programmatic access                           │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use What

**Claude Code (Interactive -- Single Session):**
- Working in the CLI interactively
- Plan mode + approval workflow
- Invoke slash commands as needed

**Claude Code (Interactive -- Agent Teams):**
- Parallel work where agents communicate
- Bug debugging with competing hypotheses
- Multi-lens code review (security + performance + tests)
- See the `agent-teams-guide` skill for details

**Feature Factory (Headless):**
- CI/CD automation, programmatic access
- Running workflows without human interaction
