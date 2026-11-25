---
name: change-dashboard
description: Use when adding or changing a view, tab, filter, chart, tile or data field of the EduIDE dashboard. Covers collect.sh, the data.json shape, index.html, local preview, checks against the raw data, README, PR and the check of the live page after the merge.
---

# Change the dashboard

Rules:
- Only public, non-archived EduIDE repos. Never read private repos or add data the public page must not show.
- No server, no build step, no new dependency. Charts are plain HTML and CSS in `index.html`.
- `collect.sh` runs with the workflow's read-only token. It must stay well under 1000 results per search query (see Limits in the README).
- `data.json` is generated and gitignored. Never commit it.
- Every number on the page must be reproducible from `data.json` with `jq`.
- No commit or push without asking the maintainer.

Steps:
1. Data first. If the view needs new fields, add them to the GraphQL queries in `collect.sh` and to the final `jq` that builds `data.json`. Keep field names in the existing camelCase style.
2. Generate the data locally: `GH_TOKEN=$(gh auth token) ./collect.sh > data.json` (about 40 s). Check the new fields with `jq`.
3. UI in `index.html`:
   - tabs: `TABS`; activity sub-views: `FLOWS`; renderers: `renderPrs`, `renderIssues`, `renderRepos`, `renderActivity`, dispatched by `render()`
   - filters go through `matches(item)`; the toolbar shows a control only on the tabs in its `data-tabs`
   - filter and view state lives in the URL: add new state to `readState` and `writeState`
   - colors are CSS variables on `:root`, with dark mode values; add both
   - week buckets are Monday-based in UTC (`MONDAY`, `weekOf`)
4. Preview: `python3 -m http.server 8000 --bind 127.0.0.1`, then open http://127.0.0.1:8000.
5. Check:
   - recount every tile and chart total with `jq` on `data.json` and compare with the page
   - no console errors
   - width 375 px: no horizontal scroll, labels readable
   - dark mode
   - filters and the URL state round-trip (reload keeps the view)
6. Update `README.md` (tabs, activity section, Limits) in the same change.
7. Branch, commit, PR. After the merge, the push to `main` deploys: check the `Dashboard` run with `gh run list --repo EduIDE/dashboard --workflow pages.yml -L 3` and the live data with `curl -s https://eduide.github.io/dashboard/data.json | jq ...`.
