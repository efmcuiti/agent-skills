---
name: ruby-dev
description: "Test-first development workflow for standalone Ruby projects (gems, CLIs) with a mandatory human review gate. Use when implementing features, fixing bugs, or making any code changes in a personal Ruby project. Enforces TDD with explicit human approval before implementation, GitHub Issue routing, and atomic commits."
disable-model-invocation: true
---

# Ruby Dev TDD Skill

**Test-Driven Development with a mandatory human review gate.**
Agents **must** obtain explicit human approval of tests **before** any implementation.

---

## Approval Token & Required ACK

**Approval token (exact):** `shipit`

**Loaded-Files ACK (after any guideline load):**

```
ACK:
- Loaded: <list exact files just read>
- Next to load: <list exact files + why they are relevant>
```

If a required path is missing or unclear, **ask** for it rather than skipping.
Never bulk-load all docs up front.

---

## When to Use This Skill

Use this skill when:
- Implementing any feature, fix, or refactor in a personal Ruby project
- Transitioning from investigation/analysis to writing code
- Writing tests or making code changes of any kind
- Using implementation verbs: "implement", "fix", "change", "create"
- Proposing solutions after analysis or investigation

**This skill is opt-in.** Invoke it explicitly as `/ruby-dev`. It is never auto-applied.

---

## Pre-flight: GitHub Issue Routing

If the user provides a GitHub issue number, run this pre-flight before starting the TDD workflow.

### Selecting the next workable item

When the user asks you to "take the next item" (no explicit issue number), do **not** just grab the first Todo — it may be blocked by unfinished dependencies. Pick the first *unblocked* task:

- A task is blocked when its `issue_dependencies_summary.blocked_by > 0`.
- Walk the Todo column in board order, skip any blocked task, and choose the first unblocked one.
- Briefly note which tasks you skipped and why (e.g. "skipped #28 — blocked by #26, #27").

See `docs/project-workflow.md` for the exact `gh api` recipe to read the blocked-by count.

**In maintenance mode**, scope the Todo scan to the **active window milestone** (skip issues in other milestones or the `no:milestone` inbox), still skip `blocked_by > 0`, and prioritize `type:bug` ahead of `type:enhancement`/`type:chore`. See [gh-sdlc/MAINTENANCE.md](../gh-sdlc/MAINTENANCE.md) for the window model.

**Step 1 — Fetch the issue type:**

```bash
gh issue view {N} --repo {owner/repo} --json labels,title | python3 -c "
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
3. Stop — do not proceed with the TDD workflow.

**If `type:task`, `type:bug`, `type:enhancement`, or `type:chore` (or no issue provided):**
Run housekeeping, then proceed with the TDD workflow. The three maintenance types are directly executable exactly like a `type:task` — the only difference is they usually have **no parent epic**, so the cascade steps below (Step 3 on start, and the epic-finish cascade at close-out) simply no-op when `parent_issue_url` is null.

### Maintenance mode (post-v1 issues)

When the repo is in maintenance mode (see [gh-sdlc/MAINTENANCE.md](../gh-sdlc/MAINTENANCE.md)), a `type:bug` / `type:enhancement` / `type:chore` issue runs the full TDD loop with these adaptations:

- **Milestone guard.** In pre-flight, confirm the issue carries a milestone (i.e. it has been triaged into a window). If it is in the `no:milestone` inbox, surface it as untriaged and stop rather than silently working it — triaging is a decision for `/gh-sdlc maintenance`, not this loop.
- **Bug = reproduce-first.** For `type:bug`, the mandatory red gate (Step 4) is explicitly a **regression test that reproduces the reported defect** before any fix. An "unexpected green" here means the repro is wrong — strengthen it until it fails for the reported reason.
- **No-parent close-out.** A standalone maintenance issue has no epic, so at close-out skip the epic-finish cascade entirely: just tick the boxes, merge, set Status → Done. Only run the cascade when `parent_issue_url` is non-null (an escalated feature's task).

**Step 2 — Housekeeping (run for every task issue):**

```bash
# 1. Assign the issue
gh issue edit {N} --add-assignee efmcuiti --repo {owner/repo}

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

# 3. Create branch (naming: em/<issue#>_<task_slug>)
git checkout -b em/{N}_{task_slug}
```

> Branch naming is `em/<issue#>_<task_slug>` (underscores, lowercase). For example: `em/12_extract_token_resolver`.

**Step 3 — Cascade the parent epic (task issues only):**

A task usually belongs to an epic. When you start a task, make sure its epic reflects that work has begun — otherwise the epic lingers in Todo while its children are underway.

1. Resolve the parent epic: `gh api repos/{owner}/{repo}/issues/{N} --jq .parent_issue_url`. The trailing number of the returned URL is the epic's issue number. If there is no parent, skip this step.
2. If the epic's project Status is **not** already In Progress or Done, set it to In Progress (same GraphQL mutation as the task) and assign it to `efmcuiti`.

See `docs/project-workflow.md` for the exact commands.

**If no issue is provided**, skip housekeeping entirely and go straight to Step 0.

---

## Recognizing Development Transition Points

Engage this workflow whenever investigation moves toward implementation:

| Investigation          | Transition Trigger      | Required Action                              |
| ---------------------- | ----------------------- | -------------------------------------------- |
| Bug analysis           | Proposing a fix         | Run pre-flight + load this skill             |
| Code exploration       | Writing test scenarios  | Engage TDD workflow                          |
| Architecture review    | Planning changes        | Start with tests                             |
| Requirements gathering | Moving to solution      | Load relevant guidelines from table below    |

**Later-in-thread implementation requires the same rigor as at the start.**

---

## Dynamic Guideline Loading

Load project docs **only as needed** — never all at once.

| File                    | When to Load                                | Purpose                                               |
| ----------------------- | ------------------------------------------- | ----------------------------------------------------- |
| `docs/architecture.md`  | **Always when writing tests for any class** | Callable/Query/Command split, pod structure, token resolver design |
| `docs/project-workflow.md` | **Always during pre-flight**             | GraphQL field IDs, branch naming, housekeeping steps  |
| `architecture-primer.md` (bundled with this skill) | When writing tests for any class **and** the project has no `docs/architecture.md` | Project-agnostic Callable/Query/Command, pod layout + spec mirroring, `docs/` conventions — fallback baseline |
| `ui-guidelines.md` (bundled with this skill) | When a task touches views, templates, or styles (`.erb`, `.html`, `.css`) | Flat BEM, CSS variables as interface, semantic + accessible HTML, the presentational review gate |
| `observability-guidelines.md` (bundled with this skill) | When a task adds or touches a service, command, or orchestrator that performs I/O, external calls, concurrency, or error handling | Structured diagnostic logging: the `rich_log`/`log_tags` contract, `scrub` + `correlation_tags` seams, `NullLogger` off-switch, and the Rails vs standalone adapters |

Per-pod guideline files will be added to this table as they are written. If you need guidance for a specific pod and no file exists yet, ask the user before proceeding.

Post a **Loaded-Files ACK** after every guideline load.

---

## Ruby-Specific Conventions

This skill is designed for standalone Ruby projects (gems, CLIs) — not Rails. The following conventions replace their Rails/pi-pod equivalents:

| Rails / pi-pod               | ruby-dev equivalent                                                   |
| ---------------------------- | --------------------------------------------------------------------- |
| FactoryBot `create`/`build`  | Plain Ruby builder helpers in `spec/support/` (e.g. `build_token_response`) |
| RSpec doubles for collaborators | Real fake classes preferred (e.g. `FakeShellRunner`, `FakeKeychain`) |
| `LoggingHelper` / `rich_log` | `puts` / `warn` / `CliPrompt`                                         |
| VCR / WebMock cassettes      | `stub_request` with inline response hashes; `WebMock.disable_net_connect!` in spec_helper |
| Global Open3/shell stubs     | Injected fake collaborators — never stub `Open3` globally             |
| `app/services/foo.rb`        | `lib/slack_status_cli/{pod}/foo.rb`                                   |
| `spec/services/foo_spec.rb`  | `spec/slack_status_cli/{pod}/foo_spec.rb`                             |

**Spec mirroring rule:** `lib/slack_status_cli/foo/bar.rb` → `spec/slack_status_cli/foo/bar_spec.rb`. Mirror the full lib path under `spec/`.

**What is NOT ported from pi-pod:** Pundit, FactoryBot gem, Strong Migrations, ActiveRecord, `LoggingHelper`. ViewComponents, Stimulus, and Turbo are not ported by default — but see the optional Rails section of the bundled `ui-guidelines.md` when the project is itself a Rails app.

---

## Mandatory TDD Workflow

### 0. Plan the Commit Sequence

Before writing any tests, plan the work as a sequence of atomic commits. For multi-file tasks, present a **simple numbered list of tasks** in plain language — no scope prefixes or commit-message jargon:

```
1. Add Callable base to lib/slack_status_cli
2. Extract ResolveToken query with spec
3. Extract PersistToken command with spec
```

**Do not pause for a separate approval here.** Fold this commit plan into the first `shipit` review package (Step 5) — present the plan alongside the first failing tests so the user approves the breakdown and the tests in one gate, rather than two back-to-back pauses. Do not make any non-test file changes before that gate regardless.

Each commit that includes a spec gets its own cycle through steps 1–8.

For small, single-commit tasks, skip this step and go straight to Step 1.

### 1. Load Guidelines

- Load `docs/architecture.md` when writing tests for any class (fall back to the bundled `architecture-primer.md` when the project has none).
- Load the bundled `ui-guidelines.md` when the task touches views, templates, or styles.
- Load `docs/project-workflow.md` during pre-flight.
- Post a **Loaded-Files ACK**.

### 2. Write Failing Tests (No Implementation)

- Work in `spec/` only. Mirror the `lib/` structure.
- Use plain Ruby builder helpers from `spec/support/` — not FactoryBot.
- Prefer real fake classes over RSpec doubles for collaborators.
- **Unexpected green?** Strengthen expectations until red.

**Presentational carve-out (UI work).** Split UI changes by their nature:

- **View logic** (helpers, presenters, scoring — anything with branching) follows normal TDD: write a failing RSpec example here as usual.
- **Pure presentation** (CSS, static ERB markup with no branching) has no natural RSpec red. Do **not** fabricate a meaningless test. Instead, in place of a failing spec, prepare the **visual-verification checklist** from `ui-guidelines.md` (rendered states, contrast, semantic structure, responsive) — optionally with a best-effort screenshot. It still goes through the same mandatory gate (Steps 4–5) and the same `shipit` token.

### 3. Handle Environment Issues (If Needed)

- **Bundler errors?** Run `bundle install` — never skip.
- **Always attempt common fixes first** before declaring tests unrunnable.
- If fixes don't work, state the issue and what you tried.

### 4. Verify Red

- Run tests and show failing examples (trim noise):
  ```bash
  bundle exec rspec spec/path/to/foo_spec.rb --format documentation
  ```
- If tests can't run after fixes, state the exact command and blocking issue.
- **Pure-presentation changes** have no red to verify (see the Step 2 carve-out). Skip this step and carry the visual-verification checklist (optional screenshot) into the gate at Step 5 instead.

### 5. Mandatory Pause (Human Gate)

- Post the **Test-Only Review Package** (see below). For pure-presentation changes, post the **visual-verification checklist** (optionally with a screenshot) in its place — the gate and `shipit` token are identical. On the **first** gate of a task, prepend the commit sequence from Step 0 so the plan and the tests are approved together.
- Follow it with a reflective prompt + structured response options.
- Use the `AskQuestion` tool in Cursor; fall back to a numbered list in other environments.
- **Do not edit non-test files until the reviewer selects "shipit".**
- If you accidentally produce implementation before approval, **undo** it and return to the gate.

### 6. Address Feedback

- If the reviewer selects a non-shipit option, act on it and return to Step 5.
- If they select "Something else", ask them to elaborate, then address and return to Step 5.

### 7. Implement Minimally

- After approval, implement the smallest change to pass tests.
- Follow the Callable/Query/Command pattern from `docs/architecture.md` (or the bundled `architecture-primer.md` when the project has no such doc).

### 8. Green, Refactor, Lint

- Refactor while green, fix lints, keep changes atomic.
- **Convention conformance (check before every commit).** Verify each changed Callable honors the project's Callable conventions — most are encapsulation rules that no Rubocop catches, so they are easy to drift on:
  - Constructor params are exposed via a `private attr_reader` and read through the readers; **never** touch a raw `@ivar` outside `initialize`.
  - `extend Callable` with explicit `*args/**kwargs/&block` forwarding (not a block-dropping `new(...).call`).
  - Each pod raises from its own `Errors` module (`Error < StandardError` + subclasses), not bare `RuntimeError`.
  - Top-level stdlib constants are `::`-qualified inside a namespaced pod (`::File`, `::Net::HTTP`).
  When the repo ships `docs/architecture.md`, its "Callable conventions" section is authoritative; otherwise fall back to the bundled `architecture-primer.md`.
- **Telemetry seam (optional, for I/O-bearing callables).** Diagnostic logging is an *injected* collaborator, never baked into a callable's own logic: orchestrators take a `telemetry:` keyword defaulting to a `NullLogger` (off), and pure queries/commands stay logger-free. Keep the human-progress channel (`CliPrompt`) and the diagnostic-event channel (`telemetry`) separate — never merge them. Every emitted message + tag routes through the `scrub` seam so secrets can't leak. See the bundled `observability-guidelines.md` for the full contract.
- **Use double-quoted strings** in all Ruby code — this holds whether or not Rubocop runs.
- **Lint changed files, but only if Rubocop is actually available.** Rubocop is optional in these projects; never assume it is installed.
  - **Detect first.** Rubocop is runnable only if it is in the bundle (or on `PATH`). Quick probe:
    ```bash
    bundle exec rubocop --version >/dev/null 2>&1 && echo runnable || echo skip
    ```
  - **If runnable**, autocorrect then check the changed files before presenting the commit message:
    ```bash
    bundle exec rubocop --autocorrect <list of changed .rb files>
    bundle exec rubocop <list of changed .rb files>
    ```
    Fix any remaining offenses and re-run the suite to confirm still green.
    > Note: If a `.rubocop.yml` is added later that disables `Style/StringLiterals` or `Style/MethodCallWithArgsParentheses`, add targeted inline-config passes matching pi-dev's Rubocop pattern.
  - **If not runnable** (e.g. no `rubocop` gem in the Gemfile, as in `slack-status-cli`), skip the lint step with a one-line note ("Rubocop not configured in this project — skipping lint") and never fail the cycle over it.

### 9. Atomic Commits

- Follow the commit plan from Step 0.
- Apply the **Atomic Commit Strategy** rules below.
- **Single-line commit messages only** (no multi-line body).
- **Commit the approved plan in one pass — do not ask before each commit.** Once the user has `shipit`-approved the tests and plan (Step 5), the commit sequence is pre-authorized: create each atomic commit as its cycle goes green, then show the resulting commits in a copyable summary:
  > Committed:
  > - `<type>(<scope>): <Title>` — `path/to/file_a.rb`, `spec/.../file_a_spec.rb`
  > - `<type>(<scope>): <Title>` — `path/to/file_b.rb`
- **Re-pause only on deviation.** If the work diverges from the approved plan (new commit not in the plan, a split/merge of planned commits, or a message that changes intent), stop and confirm that delta before committing it.

### 10. Next Cycle or Wrap Up

- If the commit plan has remaining pieces, summarize what's done and what's next, then loop back to Step 1. (No pause needed unless the work deviated from the approved plan — see Step 9.)
- If all cycles are complete, surface any unrelated issues noticed during the work: "By the way, I noticed these while working — want me to address any?" This is the only time to raise unrelated concerns.

### 11. Offer PR Creation

- **Wait until all tasks for the current session are complete.**
- Once all work is done, ask:
  > All done. Want me to open a draft PR for this branch?
- If the user accepts, **push the branch safely first**, then open the PR.

  **Push preflight (avoids the ~60s hang on a locked SSH agent):** run a fast auth check so failures surface in ~2s instead of hanging, then push:
  ```bash
  git ls-remote origin &>/dev/null || ssh -T git@github.com   # fast auth probe
  git push -u origin em/{N}_{task_slug}
  ```
  If the preflight or push fails with `sign_and_send_pubkey: signing failed ... communication with agent failed` (or `Permission denied (publickey)`), the SSH agent is locked / the key is not loaded — this is **not** a code problem. Surface this one-line remediation: "Unlock or re-add your SSH key (e.g. `ssh-add`), then I'll retry." Retry the push **once** after the user confirms. Do not loop.

- Then open the PR:
  ```bash
  gh pr create \
    --repo {owner/repo} \
    --title "{conventional commit title}" \
    --draft \
    --assignee efmcuiti \
    --body "$(cat <<'EOF'
  Closes #{N}

  ## Purpose
  {2-3 sentences from TDD discussion — what was built and why}

  ## Test plan
  - [ ] {key behavior covered by specs}
  - [ ] {edge case or error path}
  - [ ] {manual smoke test if applicable}

  <details>
  <summary>Recommended manual smoke steps</summary>

  {only when a manual smoke item exists — see the hard rule below}
  </details>

  ## Commit plan
  {numbered list from Step 0}
  EOF
  )"
  ```
- Report the PR URL back to the user.

**Collapsible manual-smoke steps (hard rule).** When any test-plan or acceptance item requires manual smoke testing — i.e. it cannot be auto-verified by the suite (a real token, hardware, network, browser, `Music.app`, etc.) — the PR body **MUST** include a collapsible block, derived from the actual code path the smoke item exercises:

```markdown
<details>
<summary>Recommended manual smoke steps</summary>

**Prereqs:** {what the user must have set up first — tokens, scopes, fixtures}

**Happy path**
1. `{exact command to run}`
2. {expected terminal/output, including the key success lines}
3. {what to verify on disk / in the workspace}

**{Key error path}**
4. `{command that triggers it}` -> {expected failure + remediation}
</details>

### Manual smoke results
<!-- Paste terminal output / screenshots per step. The close-out gate reads this section. -->
- [ ] Happy path — _paste output_
- [ ] {Key error path} — _paste output_
```

- **PR-body-only.** Keep these steps in the PR, not the issue — the issue's acceptance list stays concise.
- **Derive, don't hand-wave.** Read the relevant orchestrator/command and quote the real flags, env vars, and the messages it actually prints. Generic "run it and check it works" steps do not satisfy this rule.
- **Pair with the checkbox policy.** The manual-smoke checkbox stays unticked until proven or human-attested (see below); the collapsible block is the script the user runs to get there.
- **Give results a home.** The collapsible is the *script*; the `### Manual smoke results` section is where the *run* gets recorded. Keep that heading verbatim so the close-out evidence pre-check (Step 13.4a) finds the results reliably instead of guessing at a regex.

**Checkbox policy (issue + PR boxes):** tick boxes incrementally, but only when genuinely verified.

- At PR-open, tick the PR test-plan boxes and any issue acceptance boxes already proven during the TDD cycles (including "draft PR opened" once it is). Pre-check them in the `gh pr create` body rather than leaving them blank.
- Leave anything not yet provable for the close-out sweep (Step 13).
- **Never tick an unverifiable manual-only item** (e.g. a hardware or `Music.app` smoke test you cannot run) — leave it unchecked and surface it for the user to confirm.
- **Human-attestation exception.** If the user has already verified a manual-only item, tick the box and annotate it as human-attested. Do **not** re-run a destructive setup just to self-verify, and do not leave it blank. Attestation makes the item verified, so this is consistent with the rule above; only tick items the user has actually attested or you have proven. Attestation arrives **two** ways, and both count — annotate which one:
  - **Verbally in chat** ("I already ran the smoke test, mark it") → `- [x] Manual smoke test (verified manually by @efmcuiti)`
  - **Recorded in the PR/issue body or a comment** (a `### Manual smoke results` section with transcripts/screenshots) → `- [x] Live-Slack manual smoke (real xoxp- token) — verified manually by @efmcuiti (results in PR body)`, so the audit trail says *where* the proof lives. Grade the posted evidence before ticking (Step 13.4a).
- Update issue boxes with `gh issue edit {N} --body-file <updated>`; update PR boxes with `gh pr edit {N} --body-file <updated>`.

### 12. PR Review Response Loop (Copilot)

Copilot reviews land asynchronously (usually a minute or two after the PR opens) and recur every time you push. Every PR in this project goes through several review rounds, so treat responding to them as a first-class part of the lifecycle — not an afterthought you wait to be told about.

See `docs/project-workflow.md` → **PR review response (Copilot)** for the exact `gh`/GraphQL recipes (bot identities, listing unresolved comments, replying, resolving threads, re-requesting review). Use those recipes verbatim rather than re-deriving the API filters each time.

**When to run this step:**

1. Whenever the user signals comments exist ("we got Copilot comments").
2. As a **mandatory close-out gate**: Step 13 must not merge while any Copilot review thread is unresolved — fetch and clear them even if the user never mentioned comments.

**Classify every comment before acting:**

- `ACCEPT` — a clear bug or nit. Fix the code; add a covering spec when it's a real bug (not for pure doc/wording nits).
- `DECLINE` — wrong or intentional. Make no code change; reply with the rationale.
- **Pause and ask the user** for anything that is a genuine design or behavioral decision (not a clear bug or nit) before acting either way. Do not unilaterally redesign on Copilot's say-so.

**Strict per-round ordering** (do not reply before pushing, and re-request review only at the very end):

```
1. Fix / decide every comment in the round
2. Commit the fixes (atomic, single-line message)
3. PUSH
4. Post an inline reply to each comment, citing the now-pushed commit SHA
5. Resolve each addressed review thread
6. Re-request Copilot review — LAST, only once 1–5 are done
```

Repeat the loop for each new review round until Copilot has no open threads. Then proceed to close-out when the user asks.

### 13. Close-out (merge + project sync)

Run this **only when the user asks to merge / complete the work** — never automatically on green. It is the defined close-out lifecycle that keeps GitHub and the project board in sync (it is what was missing when boxes stayed unticked and items never reached Done).

1. **Confirm green.** Re-run the full suite (`bundle exec rspec`) and confirm 0 failures before merging.
2. **Confirm no open Copilot threads.** Run the review-thread check from Step 12; if any thread is unresolved, finish the review loop before merging.
3. **Final checkbox sweep.** Tick every remaining *verified* box on the issue and the PR, per the Checkbox Policy in Step 11. Never tick an unverifiable manual-only item — surface it for the user instead.
4. **Manual-smoke gate (mandatory, blocking).** Scan the PR and issue bodies (deduped) for any unchecked `- [ ]` that reads as manual/unverifiable — regex `smoke|manual|live token|real token|hardware|browser|Music.app|verified manually`, or any unchecked box inside a `Recommended manual smoke steps` collapsible. If none, continue. If one or more exist, this gate is never skippable — even when the user's merge request was terse ("close it") — but **do not prompt yet**: first run the evidence pre-check in 4a.

4a. **Evidence pre-check (run before any prompt).** The user may have already run the smoke test and recorded it in the PR. Confirming that is *your* job at the gate, not something the user should have to point you to.

   - **Fetch fresh, fetch whole.** `gh pr view {N} --json body --jq .body` plus `gh pr view {N} --comments`. Never reason from the box-detection grep output or from a body you read earlier in the session — the grep discards surrounding context, and the user may append results days after PR open.
   - **Locate evidence:** a heading matching `/(smoke|manual).*(result|evidence|output|run|verified)/i`, fenced transcripts containing the key lines the derived script predicted, or attached screenshots (`<img ... user-attachments ...>` / `![](...)`).
   - **Grade it against the derived collapsible, step by step:** every numbered step/branch has a matching transcript or screenshot; the transcript contains the expected key lines, in the expected order; error and edge branches are covered, not just the happy path; the commands shown match the real flags/subcommands of the code path; no `xox*-` secret leaked in the paste.
   - **Route on the grade:**
     - **Full coverage** → post a step-by-step validation summary (which evidence satisfies which step), then ask **once** via `AskQuestion` to tick and merge. Do not also run the Hold/Waive prompt — the evidence already answers it.
     - **Partial coverage** → prompt naming the **specific** missing steps, not a generic Hold/Skip.
     - **Contradicts expectations** (pasted output differs from what the code actually prints) → treat as a **failed** smoke: do not tick, surface the mismatch, and hold.
     - **No evidence found** → fall through to the Hold/Waive prompt below.

   When no evidence exists, **stop and ask** via `AskQuestion`:
   - **Hold & run the smoke test (recommended)** — abort close-out now (no merge, no Status → Done), re-surface the derived smoke script from the PR collapsible as runnable steps, and wait. When the user reports it passed, re-enter Step 13 from the top (re-confirm green + no open threads), tick the box `(verified manually by @efmcuiti)`, then merge.
   - **Skip & close (waived)** — leave the box unchecked, annotate it inline `(waived by @efmcuiti at close — not run)` on the PR (and the issue if the box is there), then proceed.
   - **Something else** — elaborate, then act.

   See `docs/project-workflow.md` → "Manual-smoke close-out gate" for the exact detection and evidence-check recipes.
5. **Merge.** Squash-merge and delete the branch:
   ```bash
   gh pr merge {N} --repo {owner/repo} --squash --delete-branch
   ```
6. **Set the task to Done.** Run the Status → Done GraphQL mutation (option ID from `docs/project-workflow.md`). Closing an issue does **not** auto-move its project item, so this explicit step is required.
7. **Verify the issue closed.** `Closes #N` in the PR body should have closed it on merge; if not, close it explicitly (`gh issue close {N}`).
8. **Sync local main.** `git checkout main && git pull --ff-only`.
9. **Epic-finish cascade.** Check whether this was the epic's last open task:
   - `gh api repos/{owner}/{repo}/issues/{EPIC}/sub_issues` lists every child with its `state`; the epic's `sub_issues_summary` (`completed`/`total`) is the quick check.
   - If **every** child is now `closed`, tick the epic's acceptance boxes, set the epic Status to Done, assign it to `efmcuiti` if unassigned, and close it.
   - Otherwise leave the epic In Progress.

See `docs/project-workflow.md` for the exact `gh`/GraphQL recipes used in steps 5, 6, and 9.

---

## Atomic Commit Strategy

Every commit must be **independently green** and **independently revertable**.

### Core Rule: Spec Files Ship with Their Implementation

A spec file and the implementation file(s) it tests belong in the **same commit**. Never commit a spec without its implementation or vice versa.

### Splitting Multi-File Changes

| File type | Commit strategy |
| --------- | --------------- |
| **Implementation + its spec** | Always together in one commit |
| **Config with no dedicated test** (Gemfile, `.rspec`, autoload config) | Separate commit(s), ordered before the spec+impl commit that depends on them |
| **Support helpers** (`spec/support/*.rb`) without a test | Separate commit, ordered before the spec that uses them |
| **Support helpers with a co-located `_spec.rb`** | Ship with the spec that exercises them |

### Commit Ordering

```
1. Config / plumbing (Gemfile changes, autoload, .rspec)
2. Spec support helpers (spec/support/ files without dedicated specs)
3. Spec + implementation (the testable behavior)
4. Docs / README updates
```

Adjust to fit the task — each commit must be independently green and revertable.

---

## Test-Only Review Package

When pausing for review, present:

- Command used (or would use) to verify red + why it fails
- RSpec outline (bulleted `describe` / `context` / `it`)
- On the first gate only: the Step 0 commit sequence, so the breakdown is approved with the tests

**For pure-presentation changes**, substitute a **visual-verification checklist** (from `ui-guidelines.md`) for the red command + RSpec outline: the rendered states to eyeball, contrast, semantic structure, and responsive behavior — plus a best-effort screenshot when a preview/browser is cheaply available. Everything else about the gate (reflective prompt, `shipit`, response options) is unchanged.

**After presenting the review package, the agent must:**

1. Write a single reflective prompt (with an emoji) that weaves together confidence in the tests with a genuine question for the reviewer. Be specific to the tests when possible. Vary the emoji, tone, and phrasing each time — it's okay to be playful. Never repeat the same prompt twice in a conversation.

2. Present structured response options. Use the `AskQuestion` tool in Cursor; use a numbered list in other environments. Options must include:
   - **shipit** (always first) — tests look good, proceed to implementation
   - **1-2 context-specific options** related to gaps or concerns in the challenge prompt
   - **Something else** (always last) — reviewer has different feedback

   If the reviewer picks "Something else", ask them to elaborate before continuing.

**Example review outputs:**

```
🔬 Pretty confident these cover the happy path and the missing-token error branch.
Less sure whether the backend fallback chain deserves its own context block here
or belongs in the resolver spec — worth a look?

1. shipit — tests look good, proceed to implementation
2. Add fallback-chain context — cover the backend precedence logic here
3. Something else — I have different feedback
```

```
🐛 If there's a bug lurking, my bet is on the shell exit-code branch.
But I've been wrong before — see anything I missed?

1. shipit — tests look good, proceed to implementation
2. Add exit-code edge case — let's cover that hunch
3. Something else — I have different feedback
```

---

## Conversation Checkpoints

| Before Action      | Ask Yourself                                 |
| ------------------ | -------------------------------------------- |
| Proposing changes  | "Am I under TDD with review gate?"           |
| Writing plans      | "Did I load guidelines + ACK?"               |
| Writing tests      | "Will I pause for review + request shipit?"  |
| Modifying code     | "Did I receive shipit before implementing?"  |
| Committing         | "Does this commit follow the atomic strategy?" |

---

## Compliance Rules

- **Loaded-Files ACK** after every guideline read
- **Unexpected Green Rule**: tighten tests until red
- **Ask if Missing Path** rather than guessing or skipping
- **No Bulk Loads** of docs
- **No implementation before shipit** — if violated, undo and return to gate
- **Callable conventions** — constructor params behind a private `attr_reader`; never read a raw `@ivar` outside `initialize`; defer to the repo's `docs/architecture.md` (or the bundled primer) for the full list
- **Stay focused**: if you notice unrelated issues, collect them and surface at Step 10 only
- **Single-line commits only** — no multi-line bodies
- **Never commit spec without implementation** or implementation without spec
- **Manual-smoke gate** — never merge past an unchecked manual/unverifiable box; at close-out check the PR for already-posted results first (Step 13.4a), then get an explicit decision
