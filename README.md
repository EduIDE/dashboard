# EduIDE Dashboard

One page with the open pull requests, open issues and release state of every public, non-archived repository in the EduIDE organization.

Page: https://eduide.github.io/dashboard/

## How it works

There is no server.
The workflow [`Dashboard`](.github/workflows/pages.yml) runs every 15 minutes, on every push to `main`, and by hand.
It runs [`collect.sh`](collect.sh), which reads the GitHub GraphQL API and writes `data.json`, and deploys `data.json` with [`index.html`](index.html) to GitHub Pages.
Private repositories are left out on purpose: the page is public.

The page groups open PRs into: needs review, changes requested, CI failing, merge conflicts, ready to merge and draft.
Issues opened in the last 7 days are highlighted, and issues without labels and assignees are marked as untriaged.
The repository table shows CI on the default branch, the latest release and the commits on the default branch since that release.
Filters are kept in the URL, so a filtered view can be shared as a link:

- search (press `/`): every word must match the title, `repo#number`, author, assignee or a label
- type (PRs, issues), repo, author, assignee (or unassigned), label (or no label), PR status
- quick filters: new (7 days), stale (no update in 14 days), untriaged (no label, no assignee)
- bot PRs are hidden unless "Show bot PRs" is ticked
- the tiles at the top set the filters that show what they count; "Reset" clears everything

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
- GitHub pauses scheduled workflows after 60 days without activity in this repository; re-enable the workflow in the Actions tab.
