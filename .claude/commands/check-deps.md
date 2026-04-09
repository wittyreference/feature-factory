---
description: Check for outdated dependencies across all packages. Use when checking deps, bumping versions, or managing package freshness.
---

Check for outdated dependencies and apply safe bumps. Language-aware — reads `ff.config.json` for the project's package manager.

## Check

First, read `ff.config.json` to determine the project language:

```bash
LANG=$(jq -r '.project.language // "javascript"' ff.config.json 2>/dev/null)
```

If `./scripts/check-deps.sh` exists, run it with `--force`. Otherwise, use language-specific commands:

| Language | List Outdated | Safe Bump | Lock File |
|----------|--------------|-----------|-----------|
| JavaScript/TypeScript | `npm outdated` | `npm update` | `package-lock.json` |
| Go | `go list -m -u all` | `go get -u ./...` | `go.sum` |
| Python | `pip list --outdated` | `pip install --upgrade <pkg>` | `requirements.txt` |
| Rust | `cargo outdated` (if installed) | `cargo update` | `Cargo.lock` |

Then read `.claude/.update-cache/deps-digest.md` if it exists and present findings.

## Apply Safe Bumps

If the user wants to apply safe bumps:

1. Run the appropriate update command for the project language (see table above)
2. Run the type check if configured: `jq -r '.typeCheck.command // empty' ff.config.json`
3. Commit lock file changes with a descriptive message listing what was bumped

## Major Upgrades

For packages with major version jumps, present them separately with a recommendation:

- **Review changelog** — link to the package's changelog/release notes
- **Check breaking changes** — note known migration concerns
- **Defer or adopt** — recommend based on risk vs. benefit

## Arguments

<user_request>
$ARGUMENTS
</user_request>
