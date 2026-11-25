#!/usr/bin/env bash
# Collects open PRs, open issues and release state of every public, non-archived
# EduIDE repo, plus 12 weeks of PR, issue and deployment activity, and prints
# data.json for index.html. Needs GH_TOKEN (read only).
set -euo pipefail

ORG="${ORG:-EduIDE}"

# shortcut: first 50 open PRs and issues per repo, raise or paginate when a repo has more
QUERY='
query($endCursor: String) {
  organization(login: "'"$ORG"'") {
    repositories(first: 10, after: $endCursor, privacy: PUBLIC, isArchived: false, orderBy: {field: NAME, direction: ASC}) {
      pageInfo { hasNextPage endCursor }
      nodes {
        name url description
        deployments(first: 1) { totalCount }
        defaultBranchRef { name target { ... on Commit { statusCheckRollup { state } } } }
        releases(first: 5, orderBy: {field: CREATED_AT, direction: DESC}) {
          nodes { tagName url publishedAt isDraft isPrerelease }
        }
        pullRequests(states: OPEN, first: 50, orderBy: {field: UPDATED_AT, direction: DESC}) {
          totalCount
          nodes {
            number title url createdAt updatedAt isDraft reviewDecision mergeable
            author { login __typename }
            labels(first: 6) { nodes { name color } }
            assignees(first: 3) { nodes { login } }
            commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
          }
        }
        issues(states: OPEN, first: 50, orderBy: {field: CREATED_AT, direction: DESC}) {
          totalCount
          nodes {
            number title url createdAt updatedAt
            author { login }
            labels(first: 6) { nodes { name color } }
            assignees(first: 3) { nodes { login } }
            comments { totalCount }
          }
        }
      }
    }
  }
}'

raw=$(gh api graphql --paginate -f query="$QUERY" | jq -s '[.[].data.organization.repositories.nodes[]]')

# Commits on the default branch since the latest published release.
ahead='{}'
while IFS=$'\t' read -r name tag branch; do
  n=$(gh api "repos/$ORG/$name/compare/$tag...$branch" -q .ahead_by 2>/dev/null || echo null)
  ahead=$(jq --arg k "$name" --argjson v "$n" '. + {($k): $v}' <<<"$ahead")
done < <(jq -r '.[] | select(.defaultBranchRef) | [.name, ([.releases.nodes[] | select(.isDraft | not)][0].tagName // empty), .defaultBranchRef.name] | select(length == 3) | @tsv' <<<"$raw")

# Activity of the last 12 weeks: PRs and issues opened or closed in that time.
since=$(jq -rn 'now - 84 * 86400 | strftime("%Y-%m-%d")')
# shortcut: search returns at most 1000 results per query, split the window when a query gets close
EVENTS_QUERY='
query($q: String!, $endCursor: String) {
  search(type: ISSUE, query: $q, first: 100, after: $endCursor) {
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest { url repository { name } author { login __typename } createdAt closedAt mergedAt }
      ... on Issue { url repository { name } author { login __typename } createdAt closedAt }
    }
  }
}'
events=$(for q in "is:pr created:>=$since" "is:pr closed:>=$since" "is:issue created:>=$since" "is:issue closed:>=$since"; do
  gh api graphql --paginate -f query="$EVENTS_QUERY" -f q="org:$ORG is:public archived:false $q" | jq -c '.data.search.nodes[]'
done | jq -s 'unique_by(.url) | map({
  type: (if has("mergedAt") then "pr" else "issue" end),
  repo: .repository.name, author: .author.login, bot: (.author.__typename == "Bot"),
  createdAt, closedAt, mergedAt
})')

# Deployments of the last 12 weeks, newest first, paged until we pass the window.
DEPLOY_QUERY='
query($owner: String!, $name: String!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    deployments(first: 100, after: $cursor, orderBy: {field: CREATED_AT, direction: DESC}) {
      pageInfo { hasNextPage endCursor }
      nodes { environment createdAt latestStatus { state } }
    }
  }
}'
deployments='[]'
# The dashboard deploys its own page every hour, which would drown everything else.
for name in $(jq -r '.[] | select(.deployments.totalCount > 0 and .name != "dashboard") | .name' <<<"$raw"); do
  cursor=null
  while :; do
    page=$(gh api graphql -f query="$DEPLOY_QUERY" -f owner="$ORG" -f name="$name" -F cursor="$cursor" -q .data.repository.deployments)
    deployments=$(jq --argjson p "$page" --arg repo "$name" --arg since "$since" \
      '. + [$p.nodes[] | select(.createdAt >= $since) | {repo: $repo, environment, createdAt, state: .latestStatus.state}]' <<<"$deployments")
    [ "$(jq --arg since "$since" '.pageInfo.hasNextPage and .nodes[-1].createdAt >= $since' <<<"$page")" = true ] || break
    cursor=$(jq -r .pageInfo.endCursor <<<"$page")
  done
done

jq --argjson ahead "$ahead" --argjson events "$events" --argjson deployments "$deployments" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  def labels: [.labels.nodes[] | {name, color}];
  {
    generatedAt: $now,
    org: "'"$ORG"'",
    repos: [.[] | {
      name, url, description,
      openPrs: .pullRequests.totalCount,
      openIssues: .issues.totalCount,
      mainCi: .defaultBranchRef.target.statusCheckRollup.state,
      release: ([.releases.nodes[] | select(.isDraft | not) | {tag: .tagName, url, publishedAt, prerelease: .isPrerelease}][0]),
      commitsSinceRelease: $ahead[.name]
    }],
    prs: [.[] | .name as $repo | .pullRequests.nodes[] | {
      repo: $repo, number, title, url, createdAt, updatedAt, isDraft, reviewDecision, mergeable,
      author: .author.login, bot: (.author.__typename == "Bot"),
      ci: .commits.nodes[0].commit.statusCheckRollup.state,
      labels: labels,
      assignees: [.assignees.nodes[].login]
    }],
    issues: [.[] | .name as $repo | .issues.nodes[] | {
      repo: $repo, number, title, url, createdAt, updatedAt,
      author: .author.login,
      labels: labels,
      assignees: [.assignees.nodes[].login],
      comments: .comments.totalCount
    }],
    events: $events,
    deployments: $deployments
  }' <<<"$raw"
