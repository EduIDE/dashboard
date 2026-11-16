# EduIDE Dashboard

One page with the open pull requests, open issues, release state and recent activity of every public, non-archived repository in the EduIDE organization.

Page: https://eduide.github.io/dashboard/

## How it works

There is no server.
The workflow [`Dashboard`](.github/workflows/pages.yml) runs every hour, on every push to `main`, and by hand.
It runs [`collect.sh`](collect.sh), which reads the GitHub GraphQL API (open items, plus PRs, issues and deployments of the last 12 weeks) and writes `data.json`, and deploys `data.json` with [`index.html`](index.html) to GitHub Pages.
Private repositories are left out on purpose: the page is public.

The header links back to this repository.
The page has four tabs: pull requests (grouped into needs review, changes requested, CI failing, merge conflicts, ready to merge and draft, empty groups hidden), issues (new in the last 7 days first), repositories (click a repo to see its PRs) and activity.
Issues opened in the last 7 days are highlighted, and issues without labels and assignees are marked as untriaged.
The repository table shows CI on the default branch, the latest release and the commits on the default branch since that release.
Filters are kept in the URL, so a filtered view can be shared as a link:

- search (press `/`): every word must match the title, `repo#number`, author, assignee or a label
- type (PRs, issues), repo, author, assignee (or unassigned), label (or no label), PR status
- quick filters: new (7 days), stale (no update in 14 days), untriaged (no label, no assignee)
- bot PRs are hidden unless "Show bot PRs" is ticked
- the tiles at the top set the filters that show what they count; "Reset" clears everything

The activity tab shows:

- the last 7 days against the 7 days before: PRs merged, opened and closed unmerged, issues opened and closed, production deployments
- the weekly flow of the last 12 weeks for PRs, issues or deployments, with opened items above the line and merged or closed ones below
- the open PRs or issues at the end of each week, rebuilt from today's open items and the opened and closed events, so no history is stored
- a deployment timeline per repository and environment for the last 14 days, with failed deployments in red
- merged PRs per repository and week

Deployments come from the GitHub Deployments API.
An environment whose name contains `test`, `staging`, `e2e`, `student` or `preview` counts as test, `github-pages` as Pages, and everything else as production.
The repo, author, search and bot filters apply to the activity tab too.

## Run it locally

```bash
GH_TOKEN=$(gh auth token) ./collect.sh > data.json
```

```bash
python3 -m http.server 8000
```

Then open http://127.0.0.1:8000.

## Limits

- `collect.sh` reads the first 50 open PRs and issues per repository.
- The activity search returns at most 1000 results per query; the 12 weeks need about 500 today.
- Reopened PRs and issues are not tracked, so the rebuilt open counts can be off by those.
- The dashboard's own Pages deployments are left out, they run every hour.
- GitHub pauses scheduled workflows after 60 days without activity in this repository; re-enable the workflow in the Actions tab.
