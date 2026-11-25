---
name: debug-refresh
description: Use when the dashboard data is stale, the page needs manual rebuilds, the hourly refresh stops, or the Dashboard workflow runs too often or fails. Covers the self-dispatch chain, the refresh-timer environment and the cron fallback.
---

# Debug the refresh

How the refresh works:
- `.github/workflows/pages.yml` has three jobs: `build` (runs `collect.sh`), `deploy` (GitHub Pages) and `next`.
- `next` waits in the `refresh-timer` environment, whose wait timer of 55 minutes holds the job without a runner, then runs `gh workflow run pages.yml` with the workflow token (`actions: write`).
- Each job has its own concurrency group. A newer run cancels the waiting `next` of the older run, so there is one timer at a time. A run cancelled that way is expected, not a failure.
- The cron `17 * * * *` is only a fallback that restarts the chain. GitHub runs this repo's cron hours late or skips it; do not rely on it.

Steps:
1. Age of the live data: `curl -s https://eduide.github.io/dashboard/data.json | jq -r .generatedAt`.
2. Recent runs: `gh run list --repo EduIDE/dashboard --workflow pages.yml -L 10 --json databaseId,event,createdAt,status,conclusion`. Normal: one `workflow_dispatch` about every 56 minutes.
3. Jobs of the newest run: `gh run view <id> --repo EduIDE/dashboard --json jobs -q '.jobs[] | "\(.name) \(.status)/\(.conclusion)"'`.
   - `build` failed: read the log (`gh run view <id> --log-failed`). Usual causes are API errors or a changed GraphQL field; reproduce with `GH_TOKEN=$(gh auth token) ./collect.sh > data.json`.
   - `next` is `waiting`: the chain is alive, wait for the timer.
   - no run in progress and no `next` waiting: the chain broke. Restart it with `gh workflow run pages.yml --repo EduIDE/dashboard` (ask first).
4. Runs every few minutes: the wait timer is gone. Check it with `gh api repos/EduIDE/dashboard/environments/refresh-timer -q .protection_rules`. Restore it with `gh api -X PUT repos/EduIDE/dashboard/environments/refresh-timer -F wait_timer=55` (repo settings change, ask first). Never merge a change that renames the environment before the new one exists with its timer: GitHub would create it without a timer.
5. Workflow disabled: `gh api repos/EduIDE/dashboard/actions/workflows -q '.workflows[] | "\(.name) \(.state)"'`. GitHub disables scheduled workflows after 60 days without activity; re-enable with `gh workflow enable pages.yml --repo EduIDE/dashboard`.
6. To compare with GitHub's scheduler in general, look at the `schedule` runs of other EduIDE repos (`gh run list --repo EduIDE/<repo> --event schedule -L 6`).
7. To wait for a result, run one background loop with `gh run list` and a deadline. Do not poll in the foreground.
