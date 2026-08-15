# Planning / Implementation

**Input:** merged Discovery findings + merged Design (ADRs, diagrams, WBS skeleton).
**Output:** `type:epic` tracking issues + `type:task` self-contained AI-ready briefs, wired with sub-issues, `addBlockedBy` dependencies, and `Related` references — each task producing one draft PR.
**Hard-stop:** the WBS **proposal** is approved with the `plan-approved` token **before any `gh issue create`** runs (see [GATES.md](./GATES.md)).

Goal of the phase: convert the Design WBS skeleton into the proven GitHub-native breakdown — the same structure validated on the `slack-status-cli` refactor — where each task body **is** the brief a future agent runs end-to-end via the project's **implementation loop**.

**Resolve the implementation-loop pointer before drafting anything** (see [SKILL.md](./SKILL.md#implementation-loop-pointer)). The pointer names the executor; the executor's own slot table supplies the test command, the lint command, and the test-file convention that this phase writes into every task brief. Resolve each slot **adapter default first, project override second** — read the adapter's `SKILL.md` for the default and the repo's `docs/project-workflow.md` for any override, and state which source you used. Do not draft briefs from memory of another project's stack.

## 1. Draft the WBS as a numbered proposal (no issues yet)

Present the breakdown as a numbered list and iterate to approval **before** creating anything. For each epic and task show: title, type, size, parent, blocked-by, and a one-line scope.

**Directive — smallest, atomic chunks of work.** This is the governing rule of the breakdown, inherited from the implementation loop's atomicity (see [SKILL.md](./SKILL.md)). Break work into **tracer-bullet vertical slices** — thin end-to-end paths over horizontal layers — and always prefer many small tasks over few large ones. A task is correctly sized when it is:

- **one draft PR** (≈ 1-6 atomic commits, tests+impl together),
- **independently demoable/verifiable**, and
- **independently revertable** without unwinding sibling tasks.

**When in doubt, split.** Signals a task is too big and should be divided: more than one new unit of substance (class, module, command, component); a `size:l` that isn't dominated by a single hard problem; an "and" in the title; a test plan that spans unrelated behaviors; or a slice that can't be reviewed on its own. Splitting is cheap here and expensive later — err toward more, thinner tasks. Size is descriptive (`size:s/m/l` reflects the residual after splitting), never a license to bundle.

**Observability check (per slice).** Read Design's observability outcome first ([DESIGN.md](./DESIGN.md)) — it has already decided whether this project has a diagnostic channel at all. **If Design recorded "not applicable", honor that and skip this check entirely**; do not resurrect a telemetry seam per-slice that the design deliberately declined, and do not manufacture a diagnostic-logger epic for a project with nothing to instrument.

Where Design did record a seam: for every task whose slice performs I/O, external calls, concurrency, or error handling, decide what it should emit on its diagnostic channel and fold that into the task's brief — the events to log, the tags/IDs that ride along, and the seam it accepts (defaulting to a null logger). If the project hasn't yet built its diagnostic-logger pod, that pod is itself an epic/tasks driven by Design's ADR, and adoption slices are `addBlockedBy` it. Reference the executor's observability guidance in the task's References so the executing agent loads the contract — the file is the executor's to name (for `ruby-dev`, `ruby-dev/observability-guidelines.md`); if the project's adapter does not exist yet, the adapter-authoring task owns that contract and there is nothing to cite. Telemetry is logic — it ships test-first like any other behavior, with a capturing-logger fake asserting what was logged.

Iterate with the user on granularity, dependency edges, and HITL/AFK marking until they approve. **This is the Planning hard-stop** — see [GATES.md](./GATES.md). Do not call `gh issue create` until `plan-approved` is given.

## 2. Epic issue template (`type:epic`)

Lifted from the proven WBS. Sections, in order:

1. **Overview** — 2-3 sentences on the area's role and the pain it relieves.
2. **Design slice** — the relevant slice of the Design ADRs/diagrams that all sub-tasks share as context (link the ADR + the locked diagram artifact + the Miro board).
3. **Mapping table** — old surface → new surface (refactor), or module → responsibility (greenfield).
4. **Area-wide conventions** — anything spanning the sub-tasks (shared fakes, injection seams, HTTP boundary rules).
5. **Sub-issues checklist** — auto-rendered from native sub-issues.
6. **Acceptance** — explicit area-completion criteria.
7. **Out of scope** — area-specific exclusions.
8. **References** — ADRs, `CONTEXT.md`, relevant executor guideline sections.

## 3. Task issue template (`type:task`)

Each task body is a **self-contained brief** the executing agent reads instead of re-deriving context. **Fill every language-specific slot from the resolved implementation-loop pointer** — never from another project's toolchain.

1. **Context** — 1-2 sentences placing this unit inside the epic; link the parent epic.
2. **Old code** — `file:line` reference into existing behavior (refactor), so the agent reads it directly.
3. **New surface** — exact entry point/signature, namespace or module path, implementation file path, test file path (per the pointer's test-file convention), and a one-sentence responsibility.
4. **Deliverable repo** — include this line **only when the code lands outside this project's repo**; omit it entirely for ordinary same-repo work. The adapter-authoring task is the standard case, since an adapter belongs in the shared skills tree rather than in one project that happens to need it. Name the repo and state plainly that the PR opens there while this issue and the board stay here, so the executing agent takes the cross-repo path in [PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md) rather than discovering at PR time that `Closes #N` cannot reach across repos.
5. **Verification** — `automated` or `attested`, stated explicitly on every task (see [below](#verification-automated-or-attested)). It decides the shape of items 6 and 8.
6. **Test plan** (`automated`) — the outline of cases at the granularity the executor's loop expects, plus a **Fixtures / Fakes** note listing the helpers and fake collaborators the tests need. Prefer purpose-built fakes over mocking frameworks. For an `attested` task, this becomes the **Verification plan**: the mechanical gate to run, and the exact judgment a human has to make.
7. **Commit plan** — the executor's commit list (usually 1-3), tests+impl together per commit.
8. **Acceptance** — machine-checkable, and **written with the pointer's own commands**: test file exists, impl exists, *the pointer's test command* green for that path, *the pointer's lint command* clean if the project configures one, draft PR opened with `Closes #<this issue>` (or, cross-repo, carrying the tracking-issue URL). An `attested` task swaps the first three for its mechanical gate plus the attestation checkbox.
9. **Linked issues** — **Parent** (epic, via `gh sub-issue add`), **Blocked by** (`addBlockedBy`), **Related** (`#N` refs).
10. **References** — parent epic, the Design ADR/section, the executor guideline sections to load.

### Verification: `automated` or `attested`

Most tasks produce code, and code has a natural failing test. Some tasks do not: migrating content into a data file, writing the README that documents the build commands, tuning a document until it fits a page budget. Those have no red to make green, and pretending otherwise produces a ceremonial test that asserts the fixture it was written from.

So every task declares which it is, and the declaration is load-bearing rather than descriptive — the executor reads it to know what its gate is gating.

| | `automated` | `attested` |
|---|---|---|
| **Use when** | the slice has behavior a test can exercise | the deliverable is content, prose, or a rendered artifact whose correctness is a human judgment |
| **Item 6 carries** | the test outline + fixtures/fakes | the mechanical gate to run + the exact judgment the human makes |
| **Acceptance opens with** | test exists, impl exists, the pointer's test command green | the mechanical gate passing (schema validate, build succeeds, artifact written) |
| **Plus** | — | one attestation checkbox per claim a human must confirm, left unticked until they do |
| **`tdd:red-gate`** | yes | **no** — there is no red gate to mark |

Two rules keep `attested` from becoming an escape hatch:

- **A mechanical gate is still mandatory.** "A human looks at it" is not a verification plan. Name what proves the artifact is well-formed — usually a command (the schema validator, the build, the renderer), or failing that a **deterministic checklist an agent can settle without judgment** (does this file declare all six slots; does it load all three bundles). Then let the human judge only what the gate cannot: is this claim true, does this read well, does it fit.
- **Never write an attestation the agent could have checked.** If a script can answer it, it belongs in the mechanical gate. `attested` covers what is genuinely unverifiable without a human, not what is inconvenient to automate.

The executor's own human gate still fires on an `attested` task — [dev-loop/LOOP.md](../dev-loop/LOOP.md) routes it to the same `shipit` pause with the verification plan in place of the test package. `attested` changes *what* is reviewed, never *whether* there is a review.

**Worked example — standalone Ruby (`/ruby-dev` pointer).** Illustrative only; the shapes below are *this pointer's* conventions, not the template's:

```
New surface:
  MyApp::Orders::Builders::TotalCents
    .call(line_items:, currency:) -> Integer
  File: lib/my_app/orders/builders/total_cents.rb
  Spec: spec/my_app/orders/builders/total_cents_spec.rb
  Responsibility: sum line items into integer cents for the given currency.

Verification: automated
Test plan: unit specs only — describe/context/it outline; real fakes over RSpec
  doubles, plain Ruby builders in spec/support/ over FactoryBot.
Acceptance: spec exists, impl exists, `bundle exec rspec <path>` green,
  Rubocop clean if the probe says it is configured, draft PR opened with
  `Closes #<this issue>`.
```

A Node project's brief would instead name its own runner, its own test-file convention, and its own lint command — resolved from that project's pointer. If you cannot state the project's test command from the pointer, **stop and ask**; do not fall back to this example.

## 4. Publish (only after `plan-approved`)

**Pre-publish label check (blocking).** Collect every label the drafted briefs reference — `type:*`, the implementation `phase:*` values Design declared, `size:*`, area labels, `tdd:red-gate` — and confirm each one exists (`gh label list --limit 100`). Create anything missing now. `gh issue create` fails per-issue on an unknown label, so skipping this check does not fail the publish cleanly: it fails it partway through, leaving some epics filed, some not, and a half-wired dependency graph to reconcile by hand.

**Pre-publish deliverable-repo check (blocking).** For every brief that declares a deliverable repo other than this project's, confirm that repo exists and has a working remote (`git ls-remote origin` inside it, or `gh repo view <DELIVERABLE_REPO>`). A brief pointing at a directory that has never been pushed is unworkable — the executor gets all the way to PR-open before it fails. Provision the remote, or hold the brief.

**Pre-publish pointer check (blocking).** Before the first `gh issue create`, re-resolve every slot — the executor's adapter table for the defaults, the repo's `docs/project-workflow.md` for overrides — and confirm that every acceptance command, test path, and file-layout claim across all drafted briefs belongs to **that** resolved set. If any brief names a command neither source owns, fix the brief — do not publish it.

**Three sources can satisfy this check, and only three:** an adapter's declared default, a project's declared override, or — while the pointer is in its [provisional state](./SKILL.md#the-provisional-state--slots-fixed-before-their-adapter-exists) — a slot recorded in `docs/project-workflow.md` **with a citation to the ADR that fixed it**. A provisional slot with no citation fails the check exactly like an invented one; the citation is the whole difference between relying on a decision and guessing. When the project has no conforming executor and no toolchain ADR either, there is nothing to derive acceptance from — follow the prescribed remedy in [SKILL.md](./SKILL.md#when-a-project-has-no-conforming-executor) rather than publishing briefs with unsatisfiable acceptance.

**When the pointer is provisional, one task retires it.** Confirm the adapter-authoring task's acceptance both requires the adapter to declare exactly the cited slots and requires the provisional block to be deleted from `docs/project-workflow.md`. Without that second half the project ships with a permanent "provisional" note and two competing slot declarations — the drift this state exists to avoid.

Then publish in dependency order so real issue numbers can be referenced:

1. Create the epics (`gh issue create --label type:epic,phase:<x>,size:<y>`).
2. For each epic, create sub-tasks (`type:task` + area/size labels; add `tdd:red-gate` to every `automated` task, and to no `attested` one) and wire them as sub-issues.
3. Wire intra-epic `addBlockedBy` edges immediately after each task is created.
4. Wire cross-epic `addBlockedBy` edges once all relevant tasks exist.
5. Add `## Related` `#N` references as a final body-edit pass.
6. Report back: project URL, per-epic issue-number ranges, and the dependency-graph summary.

See [SUBSTRATE.md](./SUBSTRATE.md) for the exact `gh sub-issue` / `addBlockedBy` mechanics.

## 5. Implementation handoff

Planning is done once the issues exist and are approved. Execution is **not** re-implemented here — each task is run by the executor named in the project's pointer (see the [pointer contract](./SKILL.md#implementation-loop-pointer)), whose shared bundles own:

- Pre-flight housekeeping (assign, Status → In Progress, branch `em/<issue#>_<task_slug>`, cascade parent epic).
- The test-first red-green-refactor loop with its own test-approval gate (distinct from this skill's phase gates).
- Atomic single-line commits, draft PR, automated-review loop, and close-out (merge + Status → Done + epic cascade).

`gh-sdlc` selects the next runnable task (open `type:task`, `blocked_by == 0`) and invokes the executor on it; it does not duplicate that loop. If the project has no conforming executor for its language, do not improvise one — follow the prescribed remedy in [SKILL.md](./SKILL.md#when-a-project-has-no-conforming-executor): the Design ADR fixes the slots, and the WBS opens with an adapter-authoring `type:chore` blocking every other task.
