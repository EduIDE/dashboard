# AGENTS.md

Instructions for coding agents (and humans) working in this repository.
`CLAUDE.md` points here.

## What this is

A static GitHub Pages site with the open PRs, open issues, release state and recent activity of every public, non-archived EduIDE repository.
Page: https://eduide.github.io/dashboard/.
There is no server: a workflow collects the data and deploys it with the page.
The [README](README.md) describes the views, the data and the limits.

## Layout

| Path | Content |
|---|---|
| `collect.sh` | Reads the GitHub GraphQL API with `gh` and `jq`, prints `data.json` |
| `index.html` | The whole page: HTML, CSS and JavaScript, no dependencies |
| `.github/workflows/pages.yml` | `build`, `deploy` and `next` (self-dispatch after 55 minutes) |
| `.claude/skills/` | Skills for the tasks below |

## Commands

| Command | Does |
|---|---|
| `GH_TOKEN=$(gh auth token) ./collect.sh > data.json` | Builds the data locally (about 40 s) |
| `python3 -m http.server 8000` | Serves the page on http://127.0.0.1:8000 |
| `gh run list --repo EduIDE/dashboard --workflow pages.yml -L 5` | Recent refreshes |
| `gh workflow run pages.yml --repo EduIDE/dashboard` | Refreshes by hand |

## Skills

| Skill | Use when |
|---|---|
| `change-dashboard` | Adding or changing a view, filter, chart or data field |
| `debug-refresh` | Data is stale, the page needs manual rebuilds, or the workflow runs too often |
| `check-repo` | A repo is missing or its numbers look wrong |

## Rules

- Only public repositories: the page is public. Private data never goes into `collect.sh` or `data.json`.
- The workflow uses only its own token (`github.token`), with the permissions in `pages.yml`. Do not add secrets.
- The `refresh-timer` environment must keep its wait timer of 55 minutes. Without it the workflow restarts itself every few minutes. Changing repo settings or environments needs the maintainer's OK.
- `data.json` is generated and gitignored.
- No new dependencies and no build step.
- Every change updates the README in the same PR.
- No commit or push without asking the maintainer.

## Writing style for docs

English, active voice, present tense, short sentences.
No em dashes or en dashes; use a hyphen.
