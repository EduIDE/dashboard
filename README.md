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
Filters (search, repo, bot PRs) are kept in the URL, so a filtered view can be shared as a link.

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
