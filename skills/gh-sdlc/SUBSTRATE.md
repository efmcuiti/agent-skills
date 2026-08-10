# Substrate — GitHub conventions + idempotent bootstrap

The GitHub-only substrate every `gh-sdlc` phase tracks against: Issues, Projects v2, native sub-issues, and `addBlockedBy` dependencies. This file is loaded **on entry** when `docs/project-workflow.md` is missing — it provisions the substrate once, then writes the IDs file that all later runs read from.

This is **plain pre-tracking plumbing, not an "Epic 0" tracking issue.** Do not file an issue to record that you bootstrapped — just run the routine. Every step is guarded (`|| true`, existence checks) so re-running is safe and idempotent.

## Mechanics live in the bundles; facts live in the project doc

A recipe copied into N repos drifts in N-1 of them. That is not hypothetical: when GitHub renamed `addBlockedBy`'s input field, the corrected recipe in this file did nothing for the stale copy sitting in a project's own doc, and a whole dependency-wiring pass failed against it.

So the split is strict, and it is the rule every phase file follows:

| Kind | Example | Lives in |
|---|---|---|
| **Mechanic** — the shape of a command, mutation, or procedure | the `addBlockedBy` mutation, the Status mutation, the manual-smoke gate, the review-response loop | the owning bundle file (this file, [CLOSEOUT.md](../gh-dev-loop/CLOSEOUT.md), [PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md)) |
| **Fact** — a per-project value substituted into a mechanic | `OWNER/REPO`, project/field/option IDs, assignee, review-bot login, branch prefix, declared phase values, milestone naming | that repo's `docs/project-workflow.md` |

`docs/project-workflow.md` is therefore a **facts file with links**, never a cookbook. When a phase needs a mechanic, read it from the bundle and substitute the project's facts — do not copy the mechanic into the project doc "for convenience", and when you find one already copied there, treat the bundle as authoritative and delete the copy.

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

# Phase — only the two the lifecycle itself owns. The implementation phases are
# named by Design (see below), because their vocabulary depends on the project.
gh label create "phase:discovery"  --color ededed || true
gh label create "phase:design"     --color ededed || true

# Size
gh label create "size:s" --color fef2c0 || true
gh label create "size:m" --color fbca04 || true
gh label create "size:l" --color d93f0b || true

# TDD gate marker (a task carries at least one implementation-loop test-approval gate)
gh label create "tdd:red-gate" --color e99695 --description "Has at least one test-approval (red) gate" || true
```

`pod:*` / area labels are project-specific — create them when the Design phase names the areas, not here.

**Implementation `phase:*` labels are deferred to Design for the same reason.** The original set (`foundation` / `extraction` / `cleanup`) came from a refactor, where "extraction" means pulling behavior out of a monolith; on a greenfield project it means nothing, and reaching for it produces labels a reader has to reinterpret. Design names the implementation phases when it names the areas, defaulting to **`foundation` / `build` / `hardening`** when the project has no better vocabulary of its own, and a refactor is free to keep `extraction` / `cleanup` because there the words are accurate. Whatever Design picks gets created then and recorded in `docs/project-workflow.md`, which is what the Implementation board view filters on.

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

The built-in **Status** field (`Todo` / `In Progress` / `Done`) is the only load-bearing field — labels carry pod/size/phase/type, so **do not recreate them as custom fields** (they drift out of sync with labels). Add an optional `Phase` single-select only if the user wants board swimlanes, and build its options from the phases this project actually declared rather than a fixed list:

```bash
gh project field-create "$PROJECT_NUMBER" --owner @me --name "Phase" \
  --data-type SINGLE_SELECT \
  --single-select-options "discovery,design,<DECLARED_IMPLEMENTATION_PHASES>" || true
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

[SKILL.md](./SKILL.md#on-entry-every-invocation)'s *On entry* calls this once for the detected phase — one call site rather than one per phase file, which is how the Design view came to be missing on a project that had already reached Planning. It no-ops when a view with that name already exists. Note that `createProjectV2View` accepts **only** `projectId`, `name`, `layout`, and `configuration` — there is **no `filter` input on create**, so the filter is applied by a follow-up `updateProjectV2View`.

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
| Planning / Implementation | `Implementation` | `label:` the implementation phases Design declared — e.g. `label:"phase:foundation","phase:build","phase:hardening"` |
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

## Status field mutation (canonical recipe)

A project's **Status does not auto-sync** with issue open/closed state — closing an issue, even via `Closes #N` on merge, leaves its project item untouched. Every Status change is therefore explicit, and this is the one place the mutation is written down. Substitute the IDs from the project's facts file.

```bash
# 1. Resolve the project item node ID for an issue number
gh project item-list <PROJECT_NUMBER> --owner <OWNER> --format json --limit 100 \
  | jq -r '.items[] | select(.content.number == <N>) | .id'

# 2. Set the Status field (swap in the option ID for the target column)
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "<PROJECT_NODE_ID>"
      itemId: "<ITEM_NODE_ID>"
      fieldId: "<STATUS_FIELD_ID>"
      value: { singleSelectOptionId: "<OPTION_ID>" }
    }) { projectV2Item { id } }
  }'
```

Adding an issue to the board, when it is not there already: `gh project item-add <PROJECT_NUMBER> --owner <OWNER> --url <ISSUE_URL>`.

## Write `docs/project-workflow.md`

Write the **facts** into `docs/project-workflow.md` — not the mechanics (see [the split above](#mechanics-live-in-the-bundles-facts-live-in-the-project-doc)). Every section below is either a per-project value or a pointer at the bundle file that owns the corresponding procedure:

- **Labels are the single source of truth** — the taxonomy table above, including the implementation `phase:*` values this project declared; Status is the only project field.
- **Project field IDs** — Project number and owner, Project node, Status field, and the three Status option IDs.
- **Board views** — each view's name and filter, so later phases reuse them instead of recreating them.
- **Repos** — the tracking repo, plus any deliverable repo that differs from it (see [CLOSEOUT.md](../gh-dev-loop/CLOSEOUT.md)).
- **Assignee, review bot, branch prefix** — the identities and conventions the implementation loop substitutes into its recipes.
- **Implementation loop** — the executor for this project, per the [pointer contract](./SKILL.md#implementation-loop-pointer), plus any slot that genuinely *overrides* the adapter's default. Ask the user if the stack is not obvious; do not guess.
- **Project-specific gate keywords** — any extra manual-smoke detection keywords beyond CLOSEOUT.md's defaults (e.g. the name of a desktop app the project drives).
- **Links, not copies** — the linked-issue mechanics below, the Status mutation above, the per-task lifecycle in [PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md) and [CLOSEOUT.md](../gh-dev-loop/CLOSEOUT.md). Reference them by link so a bundle fix reaches every project at once.

Once written, this file is the substrate's source of truth **for facts**; later `/gh-sdlc` runs read it instead of re-deriving IDs.

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
    addBlockedBy(input: { issueId: $issue, blockingIssueId: $blocker }) { issue { number } }
  }' -F issue="$ISSUE_ID" -F blocker="$BLOCKER_ID"
```

### Probe one, then loop

**Never run a bulk mutation loop without proving the mutation first.** Wire one edge, confirm the response, and only then iterate the rest. GitHub's schema moves under these recipes — `addBlockedBy`'s input field was renamed out from under this file — and a loop over 22 pairs fails 22 times just as readily as once, except that now you cannot tell which failures were the recipe and which were the data.

This applies to every bulk pass: dependency edges, sub-issue wiring, label backfills, Status sweeps.

**Iterating pairs safely.** Read them into named variables; do not rely on word-splitting:

```bash
# Correct — each pair lands in $child and $blocker regardless of shell.
printf '%s\n' "24 21" "25 21" "26 24" | while read -r child blocker; do
  echo "wiring $child blocked by $blocker"
done
```

`set -- $pair` looks equivalent and is not: **zsh does not word-split unquoted parameter expansions**, so `$pair` arrives as the single string `"24 21"` and the second value silently goes missing. The failure surfaces as an unrelated complaint about an invalid argument, several layers away from the real cause.

### Reading the relationships back

These are the queries every phase and the implementation loop use to route work — the parent lookup, the blocked check that decides whether a task is workable, and the epic-completion check that drives the close-out cascade:

```bash
# These queries always run against <TRACKING_REPO> — the issue and board live
# there even when the PR lands in a different deliverable repo.

# Parent epic of a task — the trailing number of the returned URL is the epic:
gh api repos/<TRACKING_REPO>/issues/<N> --jq .parent_issue_url

# Is a task blocked? 0 = unblocked, >0 = skip it when selecting the next item:
gh api repos/<TRACKING_REPO>/issues/<N> --jq .issue_dependencies_summary.blocked_by

# Is an epic complete? Quick summary, then per-child detail:
gh api repos/<TRACKING_REPO>/issues/<EPIC> --jq .sub_issues_summary
gh api repos/<TRACKING_REPO>/issues/<EPIC>/sub_issues --jq '[.[] | {number, state}]'
```
