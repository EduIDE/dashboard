---
name: check-repo
description: Use when asked whether a repository is on the dashboard, why a new repo is missing, or why a repo's numbers (PRs, issues, deployments, release) look wrong.
---

# Check a repo on the dashboard

Which repos are included:
- every repo of the EduIDE org that is public and not archived; new repos appear with the next refresh, no change needed
- the dashboard's own Pages deployments are left out of the activity data
- open PRs and issues: the first 50 per repo; activity: PRs and issues of the last 12 weeks; deployments from the GitHub Deployments API

Steps:
1. Newest org repos: `gh api 'orgs/EduIDE/repos?sort=created&direction=desc&per_page=10' -q '.[] | "\(.created_at) \(.name) \(.visibility) archived=\(.archived)"'`.
2. Repos in the live data and when it was built: `curl -s https://eduide.github.io/dashboard/data.json | jq -r '.generatedAt, ([.repos[].name] | join(" "))'`.
3. Details of one repo: `curl -s https://eduide.github.io/dashboard/data.json | jq '.repos[] | select(.name == "<repo>")'`, and `[.events[] | select(.repo == "<repo>")] | length` for activity.
4. Missing although public and not archived: check that the data is fresh (debug-refresh skill).
5. Private repos stay out on purpose: the page is public. Do not change that without the maintainer.
6. Numbers differ from GitHub: compare against the API (`gh pr list --repo EduIDE/<repo> --state open --json number | jq length`) and the limits in the README (50 open items per repo, reopened items not tracked, 1000 search results per query).
