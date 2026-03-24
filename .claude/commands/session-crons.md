---
description: Register recurring session-scoped checks for long sessions. Use when starting a long work session to automate drift detection, eval metrics, and pending-actions reminders.
---

# Session Crons

Register standard recurring checks using CronCreate. These run while the REPL is idle during long sessions and auto-expire after 7 days. Nothing is written to disk — jobs vanish when Claude exits.

## What Gets Registered

Set up these recurring checks:

### 1. Pending Actions Reminder (every hour)

Check if the pending actions file has unaddressed entries. If it does, print a one-line reminder with the count.

**Schedule**: `23 * * * *` (hourly at :23)

**Prompt**: Check the pending actions file. If `.meta/` exists, read `.meta/pending-actions.md`, otherwise `.claude/pending-actions.md`. If the file has entries, print: "Reminder: N pending action(s) waiting. Run /wrap-up or address them directly." If no entries or file missing, do nothing.

### 2. Doc Drift Check (every 2 hours)

Check for documentation drift by scanning for files that may have gotten out of sync with their docs.

**Schedule**: `17 */2 * * *` (every 2 hours at :17)

**Prompt**: Check if any CLAUDE.md files reference files or directories that have changed since last commit. Run `git diff --name-only HEAD` and cross-reference against doc update mappings. If drift is found, print the affected docs prefixed with "Doc drift detected:". If everything is clean, do nothing.

### 3. Distribution Drift Check (every 4 hours)

Check if upstream source has drifted from this repo.

**Schedule**: `43 */4 * * *` (every 4 hours at :43)

**Prompt**: Run `./scripts/ff-drift-check.sh --count 2>/dev/null`. If the count is greater than 0, print: "Distribution drift: N file(s) differ from upstream. Run /ff-sync to review." If 0 or script missing, do nothing.

## Registration

Register all three cron jobs using CronCreate. After registration, confirm with a summary table:

```
## Session Crons Registered

| Check              | Schedule     | Next Fire |
|--------------------|-------------|-----------|
| Pending actions    | Hourly :23  | ~HH:23    |
| Doc drift          | Every 2h :17| ~HH:17    |
| Distribution drift | Every 4h :43| ~HH:43    |

These run while idle and auto-expire after 7 days.
To list active crons: use CronList
To remove one: use CronDelete with the job ID
```

## Notes

- Jobs only fire while the REPL is idle (not mid-query)
- All jobs are session-scoped — they vanish when Claude exits
- The off-minute scheduling (:17, :23, :43) avoids fleet-wide thundering herd
- If scripts don't exist at the expected paths, skip that cron and note the skip

<user_request>
$ARGUMENTS
</user_request>
