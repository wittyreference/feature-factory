# Documentation Map

This file maps source code areas to their documentation files. Used by the documentation flywheel to suggest which docs to update when code changes.

## Mapping

| Source Area | Documentation |
|-------------|---------------|
| `.claude/hooks/` | `.claude/skills/hooks-reference.md`, root `CLAUDE.md` |
| `.claude/commands/` | Root `CLAUDE.md` (slash command table) |
| `.claude/skills/` | Root `CLAUDE.md` (documentation navigator) |
| `scripts/` | `README.md` (scripts section) |
| Root config files | `README.md` (configuration section) |

## Adding Mappings

When you add new source directories or documentation files, update this map AND the `docMappings` section in `ff.config.json` so the flywheel can suggest the right docs.

## How the Flywheel Uses This

The flywheel hook (`flywheel-doc-check.sh`) reads `ff.config.json` `docMappings` to generate suggestions. This file is the human-readable reference; `ff.config.json` is the machine-readable source.
