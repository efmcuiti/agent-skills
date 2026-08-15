# Maintenance

**Input:** a project whose initial build is shipped (a "v1") and now needs ongoing bug fixes and improvements.
**Output:** a milestone-based maintenance workflow — time-boxed release windows, a bug/enhancement/chore taxonomy, and a triage gate that routes each ask either to the project's [implementation loop](./SKILL.md#implementation-loop-pointer) or back into `/gh-sdlc`.
**Not a one-shot phase:** unlike Discovery/Design/Planning, Maintenance is a **standing mode** with three commands you re-invoke over the life of the project. It has no single terminal token; `maintenance create` carries its own approval gate before any issue is filed.

Goal of the mode: give a shipped project a durable, low-ceremony home for "asks and improvements" that **closes on its own schedule** — fixing the classic anti-pattern of a standing "Asks & Improvements" epic that never reaches Done.

## The model (hybrid: milestone = window)

Three tracking tools, each doing the job it is built for:

| Tool | Role in maintenance | Why |
|---|---|---|
| **Milestone** | The time-boxed **window** (`v1.1`, `v1.2`, ...) | Native due date + burndown; closing a milestone with open issues is a supported operation, so "close the window, roll survivors forward" is native, not a fight. |
| **`type:epic`** | Reserved for a **large feature** that earns a full `/gh-sdlc` breakdown | Keeps the epic → sub-issue cascade meaningful; a lone bug never becomes a sub-issue just to be tracked. |
| **Standalone `type:bug` / `type:enhancement` / `type:chore` issue** | Everything else | Flows straight into the implementation loop; no parent epic, so the cascade steps no-op. |

Milestone and epic are **orthogonal** — a feature-epic's tasks all carry the same milestone — so you get native time-boxing *and* the existing cascade, each where it fits.

### Why not the alternatives

- **Epic-as-window** re-introduces the never-closing pain: epics have no due date, and the cascade only auto-closes an epic when *every* child is closed, which fights the "close the window with survivors still open" roll-over.
- **A new project per window** is too heavy and loses cross-window continuity; saved views filtered by milestone give the same separation on one board.

## Taxonomy

Maintenance adds three directly-executable issue types (created by `SUBSTRATE.md`'s label block):

| Label | Meaning | Red gate in the implementation loop |
|---|---|---|
| `type:bug` | A defect against shipped behavior | A **regression test reproducing the reported defect** before any fix |
| `type:enhancement` | A small improvement / feature ask | Normal test-first red for the new behavior |
| `type:chore` | Deps, CI, docs, no-behavior-change refactor | Normal test-first red, or the pure-presentation carve-out for docs-only |

- A standalone typed issue is executed by the implementation loop exactly like a `type:task`, minus the parent-epic cascade (see `gh-dev-loop/PREFLIGHT.md` → Maintenance mode).
- `type:task` / `type:epic` / `type:research` / `type:spike` stay reserved for `/gh-sdlc` feature breakdowns.
- **`phase:*` is retired for standalone maintenance issues** — the milestone is the grouping now. `phase:*` reappears only inside an escalated feature epic if you want swimlanes.

### Inbox convention

- **`no:milestone` = the triage inbox** — a freshly filed ask sits milestone-less until triaged.
- **Assigning a milestone *is* the act of scheduling** the ask into a window.
- A saved view filtered to `no:milestone` is your inbox; one view per open milestone is your window.

## Triage gate — route each ask

Every intake is classified once, using the same atomicity signals as [PLANNING.md](./PLANNING.md):

| Signal | Route |
|---|---|
| One PR, clear approach, ≲6 commits, no open questions | **Directly executable → the implementation loop** (most bugs, chores, small enhancements) |
| Open business question, >1 substantial unit of code, an "and" in the title, `size:l` not dominated by a single hard problem, architectural impact | **Needs design → `/gh-sdlc` scoped to that one feature** (Discovery → Design → Planning), whose tasks then flow back to the implementation loop |

**When in doubt, split** — prefer a thin directly-executable slice over a bundled feature. Escalation is not a whole-project restart: `/gh-sdlc` runs **scoped to the single feature** (see [SKILL.md](./SKILL.md) → scoped maintenance features), and the substrate is already bootstrapped, so it skips `SUBSTRATE.md` and goes straight to Discovery.

## Command procedures

All three read the project's `docs/project-workflow.md` for concrete IDs and milestone naming; the generic behavior lives here. Confirm repo + owner (`gh repo view --json nameWithOwner`) before mutating anything.

### `maintenance setup`

Idempotent — safe to re-run. Puts a shipped repo into maintenance mode:

1. **Ensure labels.** Run the `type:bug` / `type:enhancement` / `type:chore` (and base taxonomy) `gh label create ... || true` block from [SUBSTRATE.md](./SUBSTRATE.md).
2. **Open the first/next window milestone.** Reuse if it already exists:
   ```bash
   TITLE=v1.1   # per docs/project-workflow.md milestone naming
   gh api "repos/<OWNER>/<REPO>/milestones" --jq '.[].title' | grep -qx "$TITLE" \
     || gh api "repos/<OWNER>/<REPO>/milestones" -f title="$TITLE" \
          -f description="Maintenance window $TITLE"
   ```
3. **Record the pointer.** Append/ensure a short **Maintenance** section in `docs/project-workflow.md`: the window-model summary, this repo's milestone naming, and a link back to this file. Land it on a branch (`em/maintenance_workflow_setup`) via a draft PR — single-line commits; markdown-only, so no fabricated tests (the implementation loop's pure-presentation carve-out).

While you are here, confirm `docs/project-workflow.md` declares an **Implementation loop** section (see [SKILL.md](./SKILL.md#implementation-loop-pointer)); if it predates the pointer contract, ask which executor the project uses and add it in the same PR.

### `maintenance create <bug|enhancement|chore> <context>`

**Defaults to plan mode and delegates to `grilling`.** No `gh issue create` until the user approves the drafted brief.

1. **Clarify + triage (plan mode).** Call the Skill tool with `grilling` on `<context>` — interview one question at a time, exploring the codebase instead of asking whenever a question is answerable there. Resolve: repro steps (bug) or desired behavior (enhancement/chore), acceptance criteria, size estimate, and the **triage route** (directly executable vs needs-design).
2. **Draft the issue brief.** A self-contained body (Context, repro/desired behavior, Acceptance, size). For a needs-design ask, the brief is the seed for the scoped `/gh-sdlc` Discovery, not a task.
3. **Approval gate.** Present the drafted brief + proposed labels + milestone-or-inbox decision, and ask the user to approve before creating. This is `maintenance create`'s hard-stop — nothing is filed without it.
4. **Create + place.** On approval:
   ```bash
   gh issue create --repo <OWNER>/<REPO> \
     --title "<title>" --body-file <brief> \
     --label "type:<bug|enhancement|chore>" --label "size:<s|m|l>" \
     --assignee efmcuiti
   # schedule into the active window, or leave milestone-less for the inbox:
   gh issue edit <N> --repo <OWNER>/<REPO> --milestone "<vX.Y>"   # omit to leave in inbox
   ```
5. **Add it to the board.** A milestone is **not** Project membership — assigning a milestone never adds the issue to the Project, so a window view (filtered `milestone:"<vX.Y>"`) cannot show it until it is a board item. Add it and set Status → Todo, reading the project number, project node ID, Status field ID, and the Todo option ID from `docs/project-workflow.md` (never hardcode them here):
   ```bash
   gh project item-add <PROJECT_NUMBER> --owner <OWNER> \
     --url https://github.com/<OWNER>/<REPO>/issues/<N>
   # resolve the new item's node id, then set Status -> Todo:
   ITEM=$(gh project item-list <PROJECT_NUMBER> --owner <OWNER> --format json --limit 200 \
     | jq -r ".items[] | select(.content.number==<N>) | .id")
   gh api graphql -f query='
     mutation {
       updateProjectV2ItemFieldValue(input: {
         projectId: "<PROJECT_NODE_ID>"
         itemId: "'"$ITEM"'"
         fieldId: "<STATUS_FIELD_ID>"
         value: { singleSelectOptionId: "<TODO_OPTION_ID>" }
       }) { projectV2Item { id } }
     }'
   ```
   > This board-add is also a prerequisite for the implementation loop: its pre-flight housekeeping sets Status via the item's node ID, which only exists once the issue is on the board. Skip it only when the issue was deliberately left in the `no:milestone` inbox (untriaged asks stay off the window board until scheduled).
6. **Route.** Directly executable → hand to the project's implementation loop. Needs design → invoke `/gh-sdlc` scoped to this feature (it creates the epic + tasks, all tagged to the same milestone).

### `maintenance close-window`

The window-close / roll-over ritual, run at each release. Milestones do **not** auto-close on issue closure — do it explicitly:

1. **Reassign survivors forward.** Move every still-open issue in the closing milestone to the next window:
   ```bash
   CUR=v1.1; NEXT=v1.2
   # ensure NEXT exists (see maintenance setup step 2), then roll survivors:
   gh issue list --repo <OWNER>/<REPO> --milestone "$CUR" --state open --json number --jq '.[].number' \
     | xargs -I{} gh issue edit {} --repo <OWNER>/<REPO> --milestone "$NEXT"
   ```
2. **Close the current milestone.**
   ```bash
   NUM=$(gh api "repos/<OWNER>/<REPO>/milestones" --jq \
     ".[] | select(.title==\"$CUR\") | .number")
   gh api -X PATCH "repos/<OWNER>/<REPO>/milestones/$NUM" -f state=closed
   ```
3. **Open the next window** if it does not already exist (reuse `maintenance setup` step 2 with `$NEXT`).

## Compliance

- **Windows close on schedule** — `maintenance close-window` at each release; a milestone must never become a de-facto never-closing epic.
- **Triage every intake once** — assign a route before work starts; unmilestoned = inbox, not in-progress.
- **Approval before filing** — `maintenance create` never runs `gh issue create` before the brief is approved.
- **On the board once scheduled** — a milestone alone never places an issue on a window view; every scheduled maintenance issue is added to the Project and set Status → Todo (also an implementation-loop housekeeping prerequisite). Only `no:milestone` inbox asks stay off the board.
- **Escalate, don't restart** — needs-design asks run `/gh-sdlc` scoped to the single feature, not the whole project.
- **Smallest atomic chunks** — inherited from [SKILL.md](./SKILL.md); when in doubt, split the ask.
