# Substrate — GitHub conventions + idempotent bootstrap

The GitHub-only substrate every `gh-sdlc` phase tracks against: Issues, Projects v2, native sub-issues, and `addBlockedBy` dependencies. This file is loaded **on entry** when `docs/project-workflow.md` is missing — it provisions the substrate once, then writes the IDs file that all later runs read from.

This is **plain pre-tracking plumbing, not an "Epic 0" tracking issue.** Do not file an issue to record that you bootstrapped — just run the routine. Every step is guarded (`|| true`, existence checks) so re-running is safe and idempotent.

## When to run

1. On any `/gh-sdlc` invocation, check for `docs/project-workflow.md`.
2. If present → read the project node ID, Status field ID, and option IDs from it; skip this routine.
3. If absent → run the routine below end-to-end, write `docs/project-workflow.md`, then proceed to phase detection.

Confirm the repo and owner with the user before creating anything (`gh repo view --json nameWithOwner`).

## Label taxonomy

```bash
# Granularity
gh label create "type:epic"     --color 5319e7 --description "Pod/area-level tracking issue" || true
gh label create "type:task"     --color 0075ca --description "Atomic PR-equivalent unit" || true
gh label create "type:research" --color 1d76db --description "Open question to resolve in Discovery" || true
gh label create "type:spike"    --color 1d76db --description "Time-boxed code investigation" || true

# Maintenance (directly-executable standalone issue types — see MAINTENANCE.md)
gh label create "type:bug"         --color d73a4a --description "Defect against shipped behavior" || true
gh label create "type:enhancement" --color a2eeef --description "Small improvement / feature ask" || true
gh label create "type:chore"       --color cfd3d7 --description "Deps, CI, docs, no-behavior-change refactor" || true

# Phase (drives board grouping; Discovery/Design added on top of the proven extraction/cleanup set)
gh label create "phase:discovery"  --color ededed || true
gh label create "phase:design"     --color ededed || true
gh label create "phase:foundation" --color ededed || true
gh label create "phase:extraction" --color ededed || true
gh label create "phase:cleanup"    --color ededed || true

# Size
gh label create "size:s" --color fef2c0 || true
gh label create "size:m" --color fbca04 || true
gh label create "size:l" --color d93f0b || true

# TDD gate marker (a task carries at least one implementation-loop test-approval gate)
gh label create "tdd:red-gate" --color e99695 --description "Has at least one test-approval (red) gate" || true
```

`pod:*` / area labels are project-specific — create them when the Design phase names the areas, not here.

## Project + custom fields

```bash
# Create the project (idempotent: reuse if a project with this title already exists)
PROJECT_NUMBER=$(gh project list --owner @me --format json \
  | jq -r --arg t "<PROJECT TITLE>" '.projects[] | select(.title==$t) | .number' | head -n1)
if [ -z "$PROJECT_NUMBER" ]; then
  PROJECT_NUMBER=$(gh project create --owner @me --title "<PROJECT TITLE>" --format json | jq -r .number)
fi
gh project link "$PROJECT_NUMBER" --owner @me --repo <OWNER>/<REPO> || true
```

The built-in **Status** field (`Todo` / `In Progress` / `Done`) is the only load-bearing field — labels carry pod/size/phase/type, so **do not recreate them as custom fields** (they drift out of sync with labels). Add an optional `Phase` single-select only if the user wants board swimlanes:

```bash
gh project field-create "$PROJECT_NUMBER" --owner @me --name "Phase" \
  --data-type SINGLE_SELECT \
  --single-select-options "discovery,design,foundation,extraction,cleanup" || true
```

## Project views

A newly created project ships with one view literally named **`View 1`**. Never leave it that way — the board is a human surface, and an unnamed view is a papercut on every visit. Name the default view after the phase it will serve first (`Discovery`) and give it the matching phase filter; later phases ensure their own view on entry.

**Every mutation in this section is guarded.** Views are quality-of-life, not load-bearing: on failure, print a manual-fallback note telling the user exactly what to set in the UI, and carry on. A view failure must never fail the bootstrap.

### Rename the default view to `Discovery`

```bash
VIEW_ID=$(gh api graphql -f query='query($p: ID!) {
    node(id: $p) { ... on ProjectV2 { views(first: 1) { nodes { id name } } } }
  }' -f p="$PROJECT_ID" --jq '.data.node.views.nodes[0].id')

gh api graphql -f query='
  mutation($v: ID!, $n: String!, $f: String!) {
    updateProjectV2View(input: { viewId: $v, name: $n, filter: $f }) {
      projectV2View { id name filter } }
  }' -f v="$VIEW_ID" -f n="Discovery" -f f='label:"phase:discovery"' \
  || echo 'NOTE: could not rename the view via the API — in the project UI, rename "View 1" to "Discovery" and set its filter to label:"phase:discovery"'
```

### Ensure a view for a phase (idempotent)

Design and Planning call this on entry; it no-ops when a view with that name already exists. Note that `createProjectV2View` accepts **only** `projectId`, `name`, `layout`, and `configuration` — there is **no `filter` input on create**, so the filter is applied by a follow-up `updateProjectV2View`.

```bash
ensure_phase_view() {  # $1 = view name, $2 = board filter
  local name="$1" filter="$2" existing new

  existing=$(gh api graphql -f query='query($p: ID!) {
      node(id: $p) { ... on ProjectV2 { views(first: 20) { nodes { id name } } } }
    }' -f p="$PROJECT_ID" | jq -r --arg n "$name" '
      .data.node.views.nodes[] | select(.name == $n) | .id')

  if [ -n "$existing" ]; then
    echo "view '$name' already exists ($existing) — skipping"
    return 0
  fi

  new=$(gh api graphql -f query='
    mutation($p: ID!, $n: String!) {
      createProjectV2View(input: { projectId: $p, name: $n, layout: TABLE_LAYOUT }) {
        projectV2View { id } }
    }' -f p="$PROJECT_ID" -f n="$name" \
    --jq '.data.createProjectV2View.projectV2View.id') || {
      echo "NOTE: could not create view '$name' — add it manually with filter: $filter"
      return 0
    }

  gh api graphql -f query='
    mutation($v: ID!, $f: String!) {
      updateProjectV2View(input: { viewId: $v, filter: $f }) { projectV2View { id name } }
    }' -f v="$new" -f f="$filter" \
    || echo "NOTE: view '$name' created but the filter did not apply — set it manually to: $filter"
}
```

| Phase | View name | Filter |
|---|---|---|
| Discovery | `Discovery` | `label:"phase:discovery"` |
| Design | `Design` | `label:"phase:design"` |
| Planning / Implementation | `Implementation` | `label:"phase:foundation","phase:extraction","phase:cleanup"` |
| Maintenance | current window `vX.Y` | `milestone:"vX.Y"` (see [MAINTENANCE.md](./MAINTENANCE.md)) |

Record the view names and filters in `docs/project-workflow.md` so later runs read them instead of guessing — and so a human who renamed a view in the UI stays the source of truth. **Never rename or delete a view the user renamed themselves**; if the expected name is absent but a same-filter view exists, report it and leave it alone.

## Capture the IDs

```bash
PROJECT_ID=$(gh project view "$PROJECT_NUMBER" --owner @me --format json | jq -r .id)
# Status field + option IDs:
gh api graphql -f query='
  query($project: ID!) {
    node(id: $project) { ... on ProjectV2 {
      field(name: "Status") { ... on ProjectV2SingleSelectField {
        id options { id name } } } } }
  }' -F project="$PROJECT_ID"
```

Record `PROJECT_ID`, the Status field ID, and the Todo/In Progress/Done option IDs.

## Write `docs/project-workflow.md`

Write the captured IDs and the per-task lifecycle into `docs/project-workflow.md`, modeled on the canonical [slack-status-cli version](/Users/efmcuiti/Phoenix/git_toys/slack-status-cli/docs/project-workflow.md). It must contain at minimum:

- **Labels are the single source of truth** — the taxonomy table above; Status is the only project field.
- **Project field IDs** — Project node, Status field, and the three Status option IDs.
- **Board views** — each view's name and filter, so later phases reuse them instead of recreating them.
- **Native issue relationships** — the `gh api .../issues/<N> --jq .parent_issue_url`, `.issue_dependencies_summary.blocked_by`, and `.sub_issues_summary` recipes.
- **Status mutation recipe** — the `updateProjectV2ItemFieldValue` GraphQL mutation with the captured IDs.
- **Per-task lifecycle** — assign → In Progress → branch (`em/<issue#>_<task_slug>`) → cascade parent epic → draft PR → close-out, matching the implementation loop's flow.
- **Implementation loop** — the executor for this project plus its test command, lint command, and test-file convention, per the [pointer contract](./SKILL.md#implementation-loop-pointer). Ask the user if the stack is not obvious; do not guess.

Once written, this file is the substrate's source of truth; later `/gh-sdlc` runs read it instead of re-deriving IDs.

## Linked-issue mechanics (used by every phase)

| Relationship | Use case | Mechanism |
|---|---|---|
| Parent ↔ sub-issue | Epic owns a task/spike | `gh sub-issue add <EPIC> <CHILD>` (positional parent first — there is **no** `--parent` flag) |
| Blocked by ↔ blocks | Task B waits on Task A | `addBlockedBy` GraphQL mutation (node IDs, not numbers) |
| Closes | PR finishes a task | `Closes #N` in PR body |
| Related | Peers sharing an idiom, not strict prereqs | `## Related` body section with `#N` refs |

```bash
# Blocked-by (node IDs):
ISSUE_ID=$(gh issue view <ISSUE> --json id -q .id)
BLOCKER_ID=$(gh issue view <BLOCKER> --json id -q .id)
gh api graphql -f query='
  mutation($issue: ID!, $blocker: ID!) {
    addBlockedBy(input: { issueId: $issue, blockedByIssueId: $blocker }) { issue { number } }
  }' -F issue="$ISSUE_ID" -F blocker="$BLOCKER_ID"
```
