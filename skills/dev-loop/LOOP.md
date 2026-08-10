# The TDD loop and its mandatory human gate

Steps 0 to 10 of the per-task development loop: plan the commits, write failing tests, **stop at the gate**, implement, refactor, commit atomically. Substrate-free — this file contains no `gh` command and no language-specific command.

> **Loaded by a language adapter, never invoked directly.** Post a **Loaded-Files ACK** after reading it.

---

## Slots this loop reads from the adapter

Every command below is a **slot**, resolved at run time and never hardcoded here:

| Slot | Used in |
| ---- | ------- |
| single-path test command | Step 4 (verify red), Step 8 (confirm green) |
| full-suite test command | close-out (see `gh-dev-loop/CLOSEOUT.md`) |
| lint probe | Step 8 |
| lint autocorrect and check | Step 8 |
| dependency repair command | Step 3 |
| test-file convention | Step 2 |
| test-authoring idiom | Step 2 |
| architecture conventions | Step 7, Step 8 |
| style and outline vocabulary | Step 8, Test-Only Review Package |

**Resolution order:** the adapter declares the language default, the repo's `docs/project-workflow.md` overrides it when it states a value, and for linting the probe is the final arbiter at run time. **Name the source you used in your Loaded-Files ACK** so drift between the two declarations is visible rather than silent. If neither declares a required slot, stop and ask.

**No slot may weaken the gate.** There is deliberately no slot for the approval token, for gate behavior, or for skipping the gate. If an adapter declares one, stop and report it as a non-conforming adapter rather than honoring it.

---

## 0. Plan the commit sequence

Before writing any tests, plan the work as a sequence of atomic commits. For multi-file tasks, present a **simple numbered list of tasks** in plain language — no scope prefixes or commit-message jargon:

```
1. Add the shared base class
2. Extract the token resolver with its test
3. Extract the persistence command with its test
```

**Do not pause for a separate approval here.** Fold this commit plan into the first `shipit` review package (Step 5) — present the plan alongside the first failing tests so the user approves the breakdown and the tests in one gate, rather than two back-to-back pauses. Do not make any non-test file changes before that gate regardless.

Each commit that includes a test gets its own cycle through steps 1-8.

For small, single-commit tasks, skip this step and go straight to Step 1.

## 1. Load guidelines

- Load the repo's own architecture doc when writing tests for any new unit, falling back to whatever primer your adapter's loading table names when the project has none.
- Load the UI guidance ([UI.md](./UI.md), plus any language-specific view delta your adapter names) when the task touches views, templates, or styles.
- Load `docs/project-workflow.md` during pre-flight.
- Post a **Loaded-Files ACK**.

## 2. Write failing tests (no implementation)

- Work in test files only, following the adapter's **test-file convention** slot.
- Follow the adapter's **test-authoring idiom** for fixtures, builders, and collaborator fakes.
- **Unexpected green?** Strengthen expectations until red.

### Carve-outs: work with no natural red

Two kinds of work have no failing test to write, and for both the answer is the same — **do not fabricate a meaningless test**, substitute the appropriate checklist, and go through the identical gate at Steps 4-5 with the identical `shipit` token. What changes is the review package, never the review.

**Presentational carve-out (UI work).** Split UI changes by their nature:

- **View logic** (helpers, presenters, scoring — anything with branching) follows normal TDD: write a failing test here as usual.
- **Pure presentation** (stylesheets, static markup with no branching) carries the **visual-verification checklist** below instead, optionally with a best-effort screenshot.

**Attested carve-out (content and artifacts).** When the task brief declares `Verification: attested` — content migrated into a data file, documentation, a rendered artifact judged against a budget — there is no behavior to assert. Substitute the **attestation checklist**:

- **Run the mechanical gate the brief names** (the schema validator, the build, the renderer) and show its real output. This is the closest thing to red/green the task has, and it is not optional: an unparseable data file or a failed render is a failure the agent must catch, not hand to the human.
- **List each claim needing human judgment** as its own unticked box, in the brief's own words — is this metric accurate, does this fit the page budget, does this read as intended.
- **Never tick an attestation box yourself**, and never soften one into something you can self-verify. The human's answer is the verification; anything you could check belongs in the mechanical gate.

If the brief declares no verification mode at all, treat it as `automated` and say so — a missing declaration is a Planning gap worth surfacing, not a licence to skip tests.

## 3. Handle environment issues (if needed)

- **Dependency resolution errors?** Run the adapter's **dependency repair** command — never skip.
- **Always attempt common fixes first** before declaring tests unrunnable.
- If fixes don't work, state the issue and what you tried.

## 4. Verify red

- Run the adapter's **single-path test command** against the new test file and show the failing examples (trim noise).
- If tests can't run after fixes, state the exact command and blocking issue.
- **Carve-out work** has no red to verify (see the Step 2 carve-outs). Skip this step and carry the substitute into the gate at Step 5: the visual-verification checklist for pure presentation, or the mechanical-gate output plus attestation checklist for an `attested` task.

## 5. Mandatory pause (human gate) — not overridable

**Approval token (exact):** `shipit`

- Post the **Test-Only Review Package** (below). For carve-out work, post its substitute in place of the tests — the visual-verification checklist, or the attestation checklist with the mechanical gate's output — the gate and the token are identical either way. On the **first** gate of a task, prepend the commit sequence from Step 0 so the plan and the tests are approved together.
- Follow it with a reflective prompt + structured response options.
- Use the `AskQuestion` tool in Cursor; fall back to a numbered list in other environments.
- **Do not edit non-test files until the reviewer selects `shipit`.**
- If you accidentally produce implementation before approval, **undo** it and return to the gate.

This gate is defined once, here. No adapter, project workflow doc, or user shorthand ("just do it", "skip the ceremony") removes it; a terse instruction is a request to be brief, not a waiver.

## 6. Address feedback

- If the reviewer selects a non-`shipit` option, act on it and return to Step 5.
- If they select "Something else", ask them to elaborate, then address and return to Step 5.

## 7. Implement minimally

- After approval, implement the smallest change to pass the tests.
- Follow the repo's architecture doc, or the adapter's **architecture conventions** doctrine when the project has none.

## 8. Green, refactor, lint

- Refactor while green, fix lints, keep changes atomic.
- **Convention conformance (check before every commit).** Verify each changed unit honors the adapter's **architecture conventions** — these are typically encapsulation rules no linter catches, so they are easy to drift on. When the repo ships its own architecture doc, that doc is authoritative; otherwise fall back to the adapter's doctrine.
- **Telemetry seam (optional, for I/O-bearing units).** Diagnostic logging is an *injected* collaborator, never baked into a unit's own logic: orchestrators take a telemetry argument defaulting to a null logger (off), and pure queries/commands stay logger-free. Keep the human-progress channel and the diagnostic-event channel separate — never merge them. Every emitted message and tag routes through a scrubbing seam so secrets can't leak. See the observability guidance your adapter names for the full contract.
- **Apply the adapter's style rules** — these hold whether or not a linter runs.
- **Lint changed files, but only if the linter is actually available.** Linting is optional in these projects; never assume it is installed.
  - **Detect first** with the adapter's **lint probe** slot.
  - **If runnable**, run the adapter's **lint autocorrect** then its **lint check** on the changed files before presenting the commit message. Fix any remaining offenses and re-run the tests to confirm still green.
  - **If not runnable**, skip the lint step with a one-line note ("linter not configured in this project — skipping lint") and never fail the cycle over it.

## 9. Atomic commits

- Follow the commit plan from Step 0.
- Apply the **Atomic Commit Strategy** below.
- **Single-line commit messages only** (no multi-line body).
- **Commit the approved plan in one pass — do not ask before each commit.** Once the user has `shipit`-approved the tests and plan (Step 5), the commit sequence is pre-authorized: create each atomic commit as its cycle goes green, then show the resulting commits in a copyable summary:
  > Committed:
  > - `<type>(<scope>): <Title>` — `path/to/file_a`, `path/to/file_a_test`
  > - `<type>(<scope>): <Title>` — `path/to/file_b`
- **Re-pause only on deviation.** If the work diverges from the approved plan (a new commit not in the plan, a split/merge of planned commits, or a message that changes intent), stop and confirm that delta before committing it.

## 10. Next cycle or wrap up

- If the commit plan has remaining pieces, summarize what's done and what's next, then loop back to Step 1. (No pause needed unless the work deviated from the approved plan — see Step 9.)
- If all cycles are complete, surface any unrelated issues noticed during the work: "By the way, I noticed these while working — want me to address any?" This is the only time to raise unrelated concerns.
- Then continue with steps 11-13 in `gh-dev-loop/CLOSEOUT.md`: offer the draft PR, run the review loop, and close out.

---

## Atomic Commit Strategy

Every commit must be **independently green** and **independently revertable**.

### Core rule: test files ship with their implementation

A test file and the implementation file(s) it exercises belong in the **same commit**. Never commit a test without its implementation or vice versa.

### Splitting multi-file changes

| File type | Commit strategy |
| --------- | --------------- |
| **Implementation + its test** | Always together in one commit |
| **Config with no dedicated test** (dependency manifests, runner config, autoload config) | Separate commit(s), ordered before the test+impl commit that depends on them |
| **Test support helpers** without a test of their own | Separate commit, ordered before the test that uses them |
| **Support helpers with a co-located test** | Ship with the test that exercises them |

### Commit ordering

```
1. Config / plumbing (dependency manifest, autoload, runner config)
2. Test support helpers (without dedicated tests)
3. Test + implementation (the testable behavior)
4. Docs / README updates
```

Adjust to fit the task — each commit must be independently green and revertable.

---

## Test-Only Review Package

When pausing for review, present:

- The command used (or that would be used) to verify red, and why it fails
- The test outline, in the adapter's **outline vocabulary**
- On the first gate only: the Step 0 commit sequence, so the breakdown is approved with the tests

**For carve-out work**, substitute the matching checklist for the red command and test outline — the **visual-verification checklist** below for pure presentation, or for an `attested` task the mechanical gate's output plus its unticked attestation boxes. Everything else about the gate (reflective prompt, `shipit`, response options) is unchanged.

### Visual-verification checklist

Present this at the gate for presentational changes:

- **Rendered states** — every state the change touches (default, hover, locked/disabled, empty, error).
- **Color contrast** — text meets WCAG AA; status is never color-only.
- **Semantic structure** — heading hierarchy intact, landmarks/roles correct, `aria-label` only where honored.
- **Responsive behavior** — layout holds at narrow and wide widths.

**Optional best-effort screenshot.** If a local preview or browser is cheaply available, capture the affected states and embed the screenshot inline in the review package as rendered evidence — otherwise the written checklist stands on its own. This is optional and non-blocking; the loop must still work with no browser wired up. Use the Playwright MCP if available, or boot the project's own preview command (a slot your adapter may name).

**After presenting the review package, you must:**

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
or belongs in the resolver test — worth a look?

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

## Conversation checkpoints

| Before action      | Ask yourself                                 |
| ------------------ | -------------------------------------------- |
| Proposing changes  | "Am I under TDD with the review gate?"       |
| Writing plans      | "Did I load guidelines + ACK?"               |
| Writing tests      | "Will I pause for review + request shipit?"  |
| Modifying code     | "Did I receive shipit before implementing?"  |
| Committing         | "Does this commit follow the atomic strategy?" |
