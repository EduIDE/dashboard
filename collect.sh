#!/usr/bin/env bash
# Collects open PRs, open issues and release state of every public, non-archived
# EduIDE repo and prints data.json for index.html. Needs GH_TOKEN (read only).
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

jq --argjson ahead "$ahead" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
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
    }]
  }' <<<"$raw"
