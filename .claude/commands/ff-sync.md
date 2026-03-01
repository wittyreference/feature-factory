# Feature Factory Sync

Detect and reconcile drift between the upstream twilio-feature-factory (battle-testing ground) and this generic feature-factory repo.

## Context

The twilio-feature-factory is where engineering patterns are discovered and hardened through real development. When a pattern proves valuable and is platform-agnostic, it should sync to this generic feature-factory. This is the reverse of plugin-sync: battle-tested patterns flow upstream → generic.

## Workflow

### 1. Run drift detection

```bash
scripts/ff-drift-check.sh --report
```

If no drift is detected, report that and stop.

### 2. Verify source repo is accessible

Check that the source repo exists at the path specified in `ff-sync-map.json` (`sourceRepo` field). If not found, report the error and stop.

### 3. Review drifted files

For each drifted file reported by the drift check:

1. Read the source file from twilio-feature-factory
2. Read the current target file in feature-factory
3. Show what changed in the source since last sync (`git diff <last-sync-commit> -- <path>`)
4. Identify which changes are platform-agnostic (should sync) vs Twilio-specific (should not)

### 4. Apply adaptations

For each syncable change, apply the documented adaptations from `ff-sync-map.json`:

- **strip-twilio-patterns**: Replace hardcoded Twilio credential patterns with config-driven `ff_credential_patterns()`
- **strip-twilio-services**: Remove Twilio service selection, voice/messaging/verify patterns
- **strip-twilio-examples**: Replace Twilio code examples with generic equivalents
- **strip-twilio-invariants**: Remove Architectural Invariants section (lives in overlay)
- **use-config-reader**: Replace hardcoded paths with `ff_config()`/`ff_config_array()` calls
- **generalize-paths**: Replace `functions/` with `trackedDirectories`, `__tests__/unit/` with configurable test paths
- **generalize-language**: Remove Twilio/serverless/TwiML language, use generic terms

Present each adapted change for user review before applying.

### 5. Verify

After applying changes:
- Run `npm run test:hooks` — all hook tests pass
- Run `npm run test:leakage` — no Twilio references leaked
- Manually verify the adapted code reads naturally

### 6. Update sync state

Update `ff-sync-state.json` with:
- `lastSyncCommit`: current HEAD of twilio-feature-factory
- `lastSyncTimestamp`: current ISO 8601 timestamp
- `syncedItems`: list of what was synced

### 7. Commit

Stage and commit with message: `sync: Update from upstream twilio-feature-factory (<count> items)`

## Arguments

$ARGUMENTS

If arguments are provided, treat them as a filter — only sync files matching the argument pattern (e.g., `/ff-sync hooks` syncs only hook files, `/ff-sync CLAUDE` syncs only CLAUDE.md sections).
