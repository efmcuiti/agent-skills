# Pre-flight: GitHub issue routing and housekeeping

The GitHub-substrate opening of the per-task development loop: pick the next workable item, route it by type, put the board in the right state, and cascade the parent epic. Language-neutral — it contains no test, lint, or build command.

> **Loaded by a language adapter, never invoked directly.** An adapter (`/ruby-dev`, and any future sibling) lists this file in its loading table and runs it before the TDD loop. Post a **Loaded-Files ACK** after reading it.

---

## Project facts come from the repo, and their absence is a hard stop

This file deliberately hardcodes **no** project identity. Every value in angle brackets below is resolved from the target repo's `docs/project-workflow.md`:

| Placeholder | Where it comes from |
| ----------- | ------------------- |
| `<OWNER/REPO>` | the repo you are working in |
| `<ASSIGNEE>` | the workflow doc's declared assignee |
| `<PROJECT_NODE_ID>`, `<STATUS_FIELD_ID>` | the workflow doc's project field table |
| `<IN_PROGRESS_OPTION_ID>`, `<TODO_OPTION_ID>`, `<DONE_OPTION_ID>` | the same table |
| `<BRANCH_PREFIX>` | the workflow doc's branch-naming convention |

**If a required fact is missing from `docs/project-workflow.md`, stop and ask for it.** Do not guess it, do not carry it over from another project you have seen, and do not fall back to a default. A wrong assignee or a wrong project node ID writes to the wrong board silently.

If the repo has no `docs/project-workflow.md` at all, say so and stop — `/gh-sdlc` provisions that file, and running the loop without it is how boards drift out of sync.

---

## Selecting the next workable item

When the user asks you to "take the next item" (no explicit issue number), do **not** just grab the first Todo — it may be blocked by unfinished dependencies. Pick the first *unblocked* task:

- A task is blocked when its `issue_dependencies_summary.blocked_by > 0`.
- Walk the Todo column in board order, skip any blocked task, and choose the first unblocked one.
- Briefly note which tasks you skipped and why (e.g. "skipped #28 — blocked by #26, #27").

See `docs/project-workflow.md` for the exact `gh api` recipe to read the blocked-by count.

**In maintenance mode**, scope the Todo scan to the **active window milestone** (skip issues in other milestones or the `no:milestone` inbox), still skip `blocked_by > 0`, and prioritize `type:bug` ahead of `type:enhancement`/`type:chore`. See [gh-sdlc/MAINTENANCE.md](../gh-sdlc/MAINTENANCE.md) for the window model.

---

## Step 1 — Fetch the issue type

```bash
gh issue view {N} --repo <OWNER/REPO> --json labels,title | python3 -c "
import sys, json
d = json.load(sys.stdin)
labels = [l['name'] for l in d['labels']]
print('title:', d['title'])
print('labels:', labels)
print('type:', next((l for l in labels if l.startswith('type:')), 'none'))
"
```

**If `type:epic`:**

1. Inform the user: "This is an Epic issue — running housekeeping only, no TDD."
2. Run the housekeeping steps below (assign + set In Progress).
3. Stop — do not proceed with the TDD loop.

**If `type:task`, `type:bug`, `type:enhancement`, or `type:chore` (or no issue provided):**
Run housekeeping, then proceed with the TDD loop. The three maintenance types are directly executable exactly like a `type:task` — the only difference is they usually have **no parent epic**, so the cascade in Step 3 and the epic-finish cascade at close-out simply no-op when `parent_issue_url` is null.

### Maintenance mode (post-v1 issues)

When the repo is in maintenance mode (see [gh-sdlc/MAINTENANCE.md](../gh-sdlc/MAINTENANCE.md)), a `type:bug` / `type:enhancement` / `type:chore` issue runs the full loop with these adaptations:

- **Milestone guard.** Confirm the issue carries a milestone (i.e. it has been triaged into a window). If it is in the `no:milestone` inbox, surface it as untriaged and stop rather than silently working it — triaging is a decision for `/gh-sdlc maintenance`, not this loop.
- **Bug = reproduce-first.** For `type:bug`, the mandatory red gate is explicitly a **regression test that reproduces the reported defect** before any fix. An "unexpected green" here means the repro is wrong — strengthen it until it fails for the reported reason.
- **No-parent close-out.** A standalone maintenance issue has no epic, so at close-out skip the epic-finish cascade entirely: just tick the boxes, merge, set Status → Done. Only run the cascade when `parent_issue_url` is non-null (an escalated feature's task).

---

## Step 2 — Housekeeping (run for every task issue)

```bash
# 1. Assign the issue
gh issue edit {N} --add-assignee <ASSIGNEE> --repo <OWNER/REPO>

# 2. Set Status → In Progress via GraphQL
# Read the project node ID, Status field ID, and option IDs from
# docs/project-workflow.md first — do NOT hardcode them here, they are
# per-project and live only in that doc.
gh api graphql -f query='
  mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "<PROJECT_NODE_ID>"
      itemId: "<ITEM_NODE_ID>"
      fieldId: "<STATUS_FIELD_ID>"
      value: { singleSelectOptionId: "<IN_PROGRESS_OPTION_ID>" }
    }) { projectV2Item { id } }
  }'

# 3. Create branch
git checkout -b <BRANCH_PREFIX>{N}_{task_slug}
```

> Branch naming is conventionally `em/<issue#>_<task_slug>` (underscores, lowercase) — for example `em/12_extract_token_resolver` — but the prefix is a project fact; read it from `docs/project-workflow.md`.

---

## Step 3 — Cascade the parent epic (task issues only)

A task usually belongs to an epic. When you start a task, make sure its epic reflects that work has begun — otherwise the epic lingers in Todo while its children are underway.

1. Resolve the parent epic: `gh api repos/<OWNER/REPO>/issues/{N} --jq .parent_issue_url`. The trailing number of the returned URL is the epic's issue number. If there is no parent, skip this step.
2. If the epic's project Status is **not** already In Progress or Done, set it to In Progress (same GraphQL mutation as the task) and assign it to `<ASSIGNEE>`.

See `docs/project-workflow.md` for the exact commands.

**If no issue is provided**, skip housekeeping entirely and go straight to the loop's commit-sequence planning step.

---

## Recognizing development transition points

Engage the loop whenever investigation moves toward implementation:

| Investigation          | Transition trigger      | Required action                              |
| ---------------------- | ----------------------- | -------------------------------------------- |
| Bug analysis           | Proposing a fix         | Run pre-flight + load the loop                |
| Code exploration       | Writing test scenarios  | Engage the TDD loop                           |
| Architecture review    | Planning changes        | Start with tests                              |
| Requirements gathering | Moving to solution      | Load the guidelines your adapter's table names |

**Later-in-thread implementation requires the same rigor as at the start.**
