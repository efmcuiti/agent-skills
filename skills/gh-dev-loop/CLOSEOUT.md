# Ship and close out: PR, review loop, merge, board sync

The GitHub-substrate tail of the per-task development loop — steps 11 to 13, picking up where `dev-loop/LOOP.md` finishes its last green cycle. Language-neutral: the one place a test command appears, it is the adapter's **full-suite** slot, never a literal.

> **Loaded by a language adapter, never invoked directly.** Post a **Loaded-Files ACK** after reading it.

**Project facts** (`<TRACKING_REPO>`, `<DELIVERABLE_REPO>`, `<ASSIGNEE>`, `<REVIEW_BOT>`, `<REVIEW_REQUEST_LOGIN>`, `<PROJECT_NODE_ID>`, `<STATUS_FIELD_ID>`, `<DONE_OPTION_ID>`, `<BRANCH_PREFIX>`, `<PROJECT_KEYWORDS>`) are resolved from the repo's `docs/project-workflow.md`. **A missing required fact is a hard stop** — ask for it rather than guessing. See [PREFLIGHT.md](./PREFLIGHT.md) for the full placeholder table.

**Two repos, when they differ.** `<DELIVERABLE_REPO>` defaults to `<TRACKING_REPO>` and the distinction is invisible on a normal task. When a task declares a different deliverable repo, the PR, the merge, and the review threads live there, while the issue, the board, and the epic cascade stay in `<TRACKING_REPO>` — see [PREFLIGHT.md](./PREFLIGHT.md) → *When the deliverable lives in another repo* for the full division.

---

## 11. Offer PR creation

- **Wait until all tasks for the current session are complete.**
- Once all work is done, ask:
  > All done. Want me to open a draft PR for this branch?
- If the user accepts, **push the branch safely first**, then open the PR.

  **Push preflight (avoids the ~60s hang on a locked SSH agent):** run a fast auth check so failures surface in ~2s instead of hanging, then push:

  ```bash
  git ls-remote origin &>/dev/null || ssh -T git@github.com   # fast auth probe
  git push -u origin <BRANCH_PREFIX>{N}_{task_slug}
  ```

  If the preflight or push fails with `sign_and_send_pubkey: signing failed ... communication with agent failed` (or `Permission denied (publickey)`), the SSH agent is locked / the key is not loaded — this is **not** a code problem. Surface this one-line remediation: "Unlock or re-add your SSH key (e.g. `ssh-add`), then I'll retry." Retry the push **once** after the user confirms. Do not loop.

- Then open the PR:

  ```bash
  gh pr create \
    --repo <DELIVERABLE_REPO> \
    --title "{conventional commit title}" \
    --draft \
    --assignee <ASSIGNEE> \
    --body "$(cat <<'EOF'
  Closes #{N}

  ## Purpose
  {2-3 sentences from the TDD discussion — what was built and why}

  ## Test plan
  - [ ] {key behavior covered by tests}
  - [ ] {edge case or error path}
  - [ ] {manual smoke test if applicable}

  <details>
  <summary>Recommended manual smoke steps</summary>

  {only when a manual smoke item exists — see the hard rule below}
  </details>

  ## Commit plan
  {numbered list from the loop's Step 0}
  EOF
  )"
  ```

- Report the PR URL back to the user.

  **Cross-repo PR body.** `Closes #{N}` only closes an issue in the PR's own repo. When `<DELIVERABLE_REPO>` differs from `<TRACKING_REPO>`, replace that line with an explicit link — `Implements <TRACKING_REPO>#{N}` written as the full `https://github.com/<TRACKING_REPO>/issues/{N}` URL — so the reference is clickable from a repo that shares no issue numbering. Do **not** leave a bare `Closes #{N}` there: it silently resolves to whatever issue happens to hold that number in the deliverable repo, or to nothing at all.

### Collapsible manual-smoke steps (hard rule)

When any test-plan or acceptance item requires manual smoke testing — i.e. it cannot be auto-verified by the suite (a real token, hardware, network, browser, an external desktop app, etc.) — the PR body **MUST** include a collapsible block, derived from the actual code path the smoke item exercises:

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
- **Pair with the checkbox policy.** The manual-smoke checkbox stays unticked until proven or human-attested; the collapsible block is the script the user runs to get there.
- **Give results a home.** The collapsible is the *script*; the `### Manual smoke results` section is where the *run* gets recorded. Keep that heading verbatim so the close-out evidence pre-check (Step 13.4a) finds the results reliably instead of guessing at a regex.

### Checkbox policy (issue + PR boxes)

Tick boxes incrementally, but only when genuinely verified.

- At PR-open, tick the PR test-plan boxes and any issue acceptance boxes already proven during the TDD cycles (including "draft PR opened" once it is). Pre-check them in the `gh pr create` body rather than leaving them blank.
- Leave anything not yet provable for the close-out sweep (Step 13).
- **Never tick an unverifiable manual-only item** (e.g. a hardware or external-app smoke test you cannot run) — leave it unchecked and surface it for the user to confirm.
- **Human-attestation exception.** If the user has already verified a manual-only item, tick the box and annotate it as human-attested. Do **not** re-run a destructive setup just to self-verify, and do not leave it blank. Attestation makes the item verified, so this is consistent with the rule above; only tick items the user has actually attested or you have proven. Attestation arrives **two** ways, and both count — annotate which one:
  - **Verbally in chat** ("I already ran the smoke test, mark it") → `- [x] Manual smoke test (verified manually by @<ASSIGNEE>)`
  - **Recorded in the PR/issue body or a comment** (a `### Manual smoke results` section with transcripts/screenshots) → `- [x] Live manual smoke (real credentials) — verified manually by @<ASSIGNEE> (results in PR body)`, so the audit trail says *where* the proof lives. Grade the posted evidence before ticking (Step 13.4a).
- Update issue boxes with `gh issue edit {N} --repo <TRACKING_REPO> --body-file <updated>`; update PR boxes with `gh pr edit {N} --repo <DELIVERABLE_REPO> --body-file <updated>`.

---

## 12. PR review response loop

Automated reviews land asynchronously (usually a minute or two after the PR opens) and recur every time you push. Every PR goes through several review rounds, so treat responding to them as a first-class part of the lifecycle — not an afterthought you wait to be told about.

The recipes below are the mechanics; `docs/project-workflow.md` supplies only the identities — `<REVIEW_BOT>` (the login that authors inline comments) and `<REVIEW_REQUEST_LOGIN>` (the login you re-request, which for bots usually differs, e.g. `Copilot` vs `copilot-pull-request-reviewer[bot]`). If the workflow doc names no review bot, ask before assuming the project has one.

**1. List open (unaddressed) inline comments** — top-level only, oldest first; replies carry a non-null `in_reply_to_id` and are filtered out:

```bash
gh api 'repos/<DELIVERABLE_REPO>/pulls/{N}/comments?sort=created&direction=asc&per_page=100' \
  --jq '.[] | select(.in_reply_to_id==null) | "id=\(.id)\t\(.path):\(.line // .original_line)\t\(.user.login)\n\(.body)\n"'

# Review summary bodies (the "reviewed N changed files" verdicts):
gh api repos/<DELIVERABLE_REPO>/pulls/{N}/reviews \
  --jq '.[] | select(.user.login | test("<REVIEW_BOT>"; "i")) | "\(.submitted_at)\t\(.state)\n\(.body)\n"'
```

**2. Reply to a comment** — only after the fix is committed and pushed, citing the SHA:

```bash
gh api repos/<DELIVERABLE_REPO>/pulls/{N}/comments/<COMMENT_ID>/replies \
  -f body="Good catch — fixed in <SHA>. <one-line explanation>."
```

**3. Fetch review-thread IDs + resolution state** (REST comments carry no thread ID; this needs GraphQL):

```bash
gh api graphql -f query='
  query($owner: String!, $name: String!, $pr: Int!) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $pr) {
        reviewThreads(first: 50) {
          nodes { id isResolved path comments(first: 1) { nodes { author { login } body } } }
        }
      }
    }
  }' -f owner=<DELIVERABLE_OWNER> -f name=<DELIVERABLE_NAME> -F pr={N} \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | "\(.id)\t\(.isResolved)\t\(.path)\t\(.comments.nodes[0].author.login)"'
```

**4. Resolve a thread** once its comment is addressed and replied to:

```bash
gh api graphql -f query='mutation { resolveReviewThread(input: { threadId: "<PRRT_...>" }) { thread { isResolved path } } }'
```

**5. Re-request review** — LAST, only once every comment in the round is fixed, pushed, replied to, and resolved:

```bash
gh api repos/<DELIVERABLE_REPO>/pulls/{N}/requested_reviewers \
  -X POST -f "reviewers[]=<REVIEW_REQUEST_LOGIN>"
```

**Close-out gate:** before the Step 13 merge, re-run recipe 3 — if any thread shows `isResolved=false`, the review loop is not done.

**When to run this step:**

1. Whenever the user signals comments exist ("we got review comments").
2. As a **mandatory close-out gate**: Step 13 must not merge while any review thread is unresolved — fetch and clear them even if the user never mentioned comments.

**Classify every comment before acting:**

- `ACCEPT` — a clear bug or nit. Fix the code; add a covering test when it's a real bug (not for pure doc/wording nits).
- `DECLINE` — wrong or intentional. Make no code change; reply with the rationale.
- **Pause and ask the user** for anything that is a genuine design or behavioral decision (not a clear bug or nit) before acting either way. Do not unilaterally redesign on a bot's say-so.

**Strict per-round ordering** (do not reply before pushing, and re-request review only at the very end):

```
1. Fix / decide every comment in the round
2. Commit the fixes (atomic, single-line message)
3. PUSH
4. Post an inline reply to each comment, citing the now-pushed commit SHA
5. Resolve each addressed review thread
6. Re-request review — LAST, only once 1-5 are done
```

Repeat the loop for each new review round until there are no open threads. Then proceed to close-out when the user asks.

---

## 13. Close-out (merge + project sync)

Run this **only when the user asks to merge / complete the work** — never automatically on green. It is the defined close-out lifecycle that keeps GitHub and the project board in sync.

1. **Confirm green.** Re-run the full suite using the adapter's **full-suite test command** slot and confirm 0 failures before merging. For a task the brief declared `Verification: attested`, re-run the mechanical gate it named instead (the validator, the build, the renderer) — the suite may have nothing to say about a content change, but the artifact must still be well-formed at merge time.
2. **Confirm no open review threads.** Run the check from Step 12; if any thread is unresolved, finish the review loop before merging.
3. **Final checkbox sweep.** Tick every remaining *verified* box on the issue and the PR, per the Checkbox Policy in Step 11. Never tick an unverifiable manual-only item — surface it for the user instead.
4. **Manual-smoke gate (mandatory, blocking).** Scan the PR and issue bodies (deduped) for any unchecked `- [ ]` that reads as manual/unverifiable — regex `smoke|manual|live token|real token|hardware|browser|verified manually|attest`, plus any project-specific keywords declared in `docs/project-workflow.md`, or any unchecked box inside a `Recommended manual smoke steps` collapsible. If none, continue. If one or more exist, this gate is never skippable — even when the user's merge request was terse ("close it") — but **do not prompt yet**: first run the evidence pre-check in 4a.

4a. **Evidence pre-check (run before any prompt).** The user may have already run the smoke test and recorded it in the PR. Confirming that is *your* job at the gate, not something the user should have to point you to.

   - **Fetch fresh, fetch whole.** `gh pr view {N} --json body --jq .body` plus `gh pr view {N} --comments`. Never reason from the box-detection grep output or from a body you read earlier in the session — the grep discards surrounding context, and the user may append results days after PR open.
   - **Locate evidence:** a heading matching `/(smoke|manual).*(result|evidence|output|run|verified)/i`, fenced transcripts containing the key lines the derived script predicted, or attached screenshots (`<img ... user-attachments ...>` / `![](...)`).
   - **Grade it against the derived collapsible, step by step:** every numbered step/branch has a matching transcript or screenshot; the transcript contains the expected key lines, in the expected order; error and edge branches are covered, not just the happy path; the commands shown match the real flags/subcommands of the code path; no secret leaked in the paste.
   - **Route on the grade:**
     - **Full coverage** → post a step-by-step validation summary (which evidence satisfies which step), then ask **once** via `AskQuestion` to tick and merge. Do not also run the Hold/Waive prompt — the evidence already answers it.
     - **Partial coverage** → prompt naming the **specific** missing steps, not a generic Hold/Skip.
     - **Contradicts expectations** (pasted output differs from what the code actually prints) → treat as a **failed** smoke: do not tick, surface the mismatch, and hold.
     - **No evidence found** → fall through to the Hold/Waive prompt below.

   When no evidence exists, **stop and ask** via `AskQuestion`:
   - **Hold & run the smoke test (recommended)** — abort close-out now (no merge, no Status → Done), re-surface the derived smoke script from the PR collapsible as runnable steps, and wait. When the user reports it passed, re-enter Step 13 from the top (re-confirm green + no open threads), tick the box `(verified manually by @<ASSIGNEE>)`, then merge.
   - **Skip & close (waived)** — leave the box unchecked, annotate it inline `(waived by @<ASSIGNEE> at close — not run)` on the PR (and the issue if the box is there), then proceed.
   - **Something else** — elaborate, then act.

   **Recipes.** `docs/project-workflow.md` contributes only the project's extra detection keywords; the mechanics are here.

   ```bash
   # Detect an unchecked manual/unverifiable box across PR + issue bodies (deduped).
   # Non-empty output => run the gate before merging.
   { gh pr view {N} --repo <DELIVERABLE_REPO> --json body --jq .body; \
     gh issue view <ISSUE> --repo <TRACKING_REPO> --json body --jq .body; } \
     | grep -E '^[[:space:]]*- \[ \]' \
     | grep -iE 'smoke|manual|live token|real token|hardware|browser|verified manually|attest<PROJECT_KEYWORDS>' \
     | sort -u

   # Evidence pre-check: fetch the whole body AND the comments fresh, then locate evidence.
   gh pr view {N} --json body --jq .body > /tmp/pr_body.md
   gh api repos/<DELIVERABLE_REPO>/issues/{N}/comments --jq '.[].body' > /tmp/pr_comments.md
   grep -inE '^#{1,4} .*(smoke|manual).*(result|evidence|output|run|verified)' /tmp/pr_body.md /tmp/pr_comments.md
   grep -cE '<img |!\[' /tmp/pr_body.md /tmp/pr_comments.md   # per file: LINES holding an image ref, not an image count
   gh pr view {N} --comments   # then read them in context (also surfaces review bodies)
   ```

   Annotating the box after the routing decision — edit the fetched body, then push it back with `gh pr edit {N} --repo <DELIVERABLE_REPO> --body-file` (and `gh issue edit <ISSUE> --repo <TRACKING_REPO> --body-file` when the same box lives on the issue):

   - **waived** → append ` (waived by @<ASSIGNEE> at close — not run)` to the matched `- [ ]` line, left unticked.
   - **evidence-attested** → change the line to `- [x] ... — verified manually by @<ASSIGNEE> (results in <PR body | comment <id>>)`, naming the location the pre-check actually found.

5. **Merge.** Squash-merge and delete the branch:

   ```bash
   gh pr merge {N} --repo <DELIVERABLE_REPO> --squash --delete-branch
   ```

6. **Set the task to Done.** Run the canonical Status mutation from [gh-sdlc/SUBSTRATE.md](../gh-sdlc/SUBSTRATE.md) with `<DONE_OPTION_ID>`. Closing an issue does **not** auto-move its project item, so this explicit step is required.
7. **Verify the issue closed.** `Closes #N` in the PR body should have closed it on merge; if not, close it explicitly (`gh issue close {N} --repo <TRACKING_REPO>`). **A cross-repo PR never auto-closes**, so when the repos differ this explicit close is the normal path rather than the fallback.
8. **Sync local main.** `git checkout main && git pull --ff-only` in `<DELIVERABLE_REPO>`'s working tree — the one the branch was merged into.
9. **Epic-finish cascade.** Check whether this was the epic's last open task:
   - `gh api repos/<TRACKING_REPO>/issues/{EPIC}/sub_issues` lists every child with its `state`; the epic's `sub_issues_summary` (`completed`/`total`) is the quick check.
   - If **every** child is now `closed`, tick the epic's acceptance boxes, set the epic Status to Done, assign it to `<ASSIGNEE>` if unassigned, and close it.
   - Otherwise leave the epic In Progress.

The mechanics for steps 6 and 9 live in [gh-sdlc/SUBSTRATE.md](../gh-sdlc/SUBSTRATE.md) — *Status field mutation* and *Reading the relationships back*. `docs/project-workflow.md` supplies the IDs and repo they take, nothing more.
