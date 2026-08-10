---
name: gh-sdlc
description: Walk any project (greenfield or refactor) on a GitHub substrate through its software development lifecycle — Discovery, Design, then Planning/Implementation — with a mandatory human-approval hard-stop between every phase. Language- and tooling-agnostic; per-task execution is delegated to the project's implementation-loop pointer. Use when the user explicitly invokes /gh-sdlc to take a set of specs from research, through solution design, into an AI-ready epic/task breakdown.
disable-model-invocation: true
---

# gh-sdlc

**A phased SDLC router with a mandatory human gate between every phase.**
It moves **any project, in any language** through **Discovery → Design → Planning/Implementation**, tracked on **GitHub** (Issues, Projects v2, native sub-issues, `addBlockedBy`). Each phase ends at a hard-stop the user **must** approve before the next begins. The GitHub substrate is the only hard coupling; the toolchain is resolved per project via the [implementation-loop pointer](#implementation-loop-pointer).

**This skill is opt-in.** Invoke it explicitly as `/gh-sdlc` (optionally `/gh-sdlc <discovery|design|planning>`, or a Discovery sub-verb: `discovery run <N>`, `discovery run --all`, `discovery consolidate`). It is never auto-applied.

Once a project has shipped its v1, it also serves as the **maintenance** entry point: `/gh-sdlc maintenance <setup|create|close-window>` (see [MAINTENANCE.md](./MAINTENANCE.md)).

It **delegates, never duplicates**: `grill-me` for question elicitation, `grill-with-docs` for ADRs + `CONTEXT.md`, `to-issues`/`to-prd` for breakdown vocabulary, and the project's **implementation loop** (`ruby-dev` for standalone Ruby) for the per-task execution loop.

---

## Governing directive: smallest, atomic chunks of work

This skill is the upstream extension of the implementation loop's atomicity. Where the executor makes every *commit* the smallest independently-green, independently-revertable unit, `gh-sdlc` applies the same instinct to every *artifact it produces*: **favor many small atomic units over few large ones, at every phase.**

- **Discovery:** one resolvable question per research/spike issue — never a bundle of questions.
- **Design:** one decision per ADR; one concern per diagram. Split rather than merge.
- **Planning:** the smallest vertical slice that is still demoable — one task ≈ one draft PR ≈ a handful of the executor's atomic commits. Prefer thin tracer bullets over thick layers.

When in doubt, **split.** A unit is too big if it can't be reviewed, approved, or reverted on its own. This directive outranks convenience — never collapse two atomic units to save ceremony.

---

## Loaded-Files ACK (after any guideline load)

```
ACK:
- Loaded: <list exact files just read>
- Next to load: <list exact files + why they are relevant>
```

Never bulk-load all reference files up front. Load one phase file at a time. If a required path is missing or unclear, **ask** rather than skipping.

---

## On entry (every invocation)

1. **Resolve the substrate.** Check for `docs/project-workflow.md` in the target repo. If it is missing, load [SUBSTRATE.md](./SUBSTRATE.md) and run the idempotent setup routine (provision Project + labels + fields, capture IDs, write the file) before anything else. If it exists, read it for the project/field IDs and proceed.
2. **Resolve the implementation-loop pointer** from `docs/project-workflow.md` (see [below](#implementation-loop-pointer)). Every later reference to "the implementation loop" means that skill.
3. **Detect the current phase** from repo state (table below), or honor an explicit `/gh-sdlc <phase>` argument. A `/gh-sdlc maintenance <verb>` argument routes straight to Maintenance mode regardless of repo state; a `discovery run`/`discovery consolidate` verb routes to that Discovery stage.
4. **Confirm greenfield vs refactor** if it is not already obvious — it changes the Discovery shape.
5. **Load only that phase's reference file** (or [MAINTENANCE.md](./MAINTENANCE.md) for a maintenance verb), post a Loaded-Files ACK, and run it. Load [GATES.md](./GATES.md) when you reach the phase boundary.

### Phase detection

| Repo signal | Current phase | Load |
|---|---|---|
| No Discovery epic / no `docs/discovery/` | **Discovery — Stage 1** (propose + file questions) | [DISCOVERY.md](./DISCOVERY.md) |
| Discovery epic exists with **open** question sub-issues | **Discovery — execution**: report the run menu, do not re-elicit | [DISCOVERY.md](./DISCOVERY.md) |
| All question sub-issues closed, no findings PR / no `docs/discovery/<topic>.md` | **Discovery — Stage 2** (consolidate) | [DISCOVERY.md](./DISCOVERY.md) |
| Discovery findings PR merged, no Design epic / no new ADRs | **Design** | [DESIGN.md](./DESIGN.md) |
| Design PR merged (ADRs + diagrams landed), no implementation epics | **Planning** | [PLANNING.md](./PLANNING.md) |
| Implementation epics/tasks exist | **Implementation handoff** | per task: the project's [implementation loop](#implementation-loop-pointer) |
| v1 shipped; ongoing bugs/improvements (or an explicit `maintenance` verb) | **Maintenance** | [MAINTENANCE.md](./MAINTENANCE.md) |

When detection is ambiguous, state what you found and ask which phase to run.

---

## The three phases (four hard-stops)

| Phase | Input | Produces | Hard-stop artifact | Gate token |
|---|---|---|---|---|
| **Discovery — Stage 1** | a set of specs | `type:research`/`type:spike` issues under a Discovery epic | approved **question proposal**, before any `gh issue create` | `discovery-approved` |
| **Discovery — Stage 2** | closed question issues (answered via `discovery run`) | `docs/discovery/<topic>.md` | findings **PR** you review/merge | `findings-approved` |
| **Design** | merged Discovery findings | ADRs in `docs/adr/` + `CONTEXT.md` + Miro→`docs/` diagrams | design **PR** you review/merge | `design-approved` |
| **Planning** | Discovery + Design | epic/task WBS proposal (AI-ready briefs) | approved **WBS proposal**, before any `gh issue create` | `plan-approved` |

**Discovery is user-driven in the middle.** Stage 1 ends when the question issues exist — the skill files them and stops. The user then decides when and at what parallelism to work them (`/gh-sdlc discovery run <N>` or `run --all`), exactly as they decide when to run an implementation task. Stage 2 consolidates the answers. See [DISCOVERY.md](./DISCOVERY.md).

After `plan-approved`, publish the issues in dependency order and hand each task to the project's **implementation loop** (which runs its own test-approval gate). See [GATES.md](./GATES.md) for the gate protocol — **no phase-advancing or issue-creating action happens until the phase token is given.**

---

## Implementation-loop pointer

`gh-sdlc` owns the lifecycle **up to and including the issue breakdown**. It deliberately does not own per-task execution — that belongs to a language-specific **implementation loop**, declared once per project in `docs/project-workflow.md`. Only the executor line is required:

```markdown
## Implementation loop

- **Executor:** `/ruby-dev`
```

Every other slot (test command, lint command, test-file convention) is declared by the adapter as its language default. A project states one **only to override** the default — for example to record that a linter the adapter names is not installed in this repo:

```markdown
- **Lint command:** `bundle exec rubocop` — **not configured in this project** (no `rubocop` gem in the `Gemfile`)
```

**Resolution.** Read this on entry (step 2 of *On entry*). Everywhere this skill, [PLANNING.md](./PLANNING.md), or [MAINTENANCE.md](./MAINTENANCE.md) says "the implementation loop", it means the executor declared there. Slots resolve **adapter default first, project override second**; when a phase needs a concrete command, read both and say which source supplied it. If the section is missing, **ask the user which executor the project uses and record their answer** in `docs/project-workflow.md` before proceeding. Never infer a Ruby executor because the GitHub substrate looks familiar, and never invent test or lint commands for a stack you have not confirmed.

### The contract an executor must satisfy

A conforming executor is a **dev-loop adapter**: a skill whose `SKILL.md` declares all nine language slots and loads the three shared stage files. That is checkable by inspection, which is the point — conformance is a structural property, not a judgment call.

**Structural test.** The adapter must:

1. Declare the **six mechanical slots** in a table: single-path test command, full-suite test command, lint probe, lint autocorrect and check, dependency repair, test-file convention.
2. Declare the **three doctrine sections**: test-authoring idiom, architecture conventions, style and outline vocabulary.
3. List and load `gh-dev-loop/PREFLIGHT.md`, `dev-loop/LOOP.md`, and `gh-dev-loop/CLOSEOUT.md`.
4. Declare **no** slot for the approval token, gate behavior, or skipping the gate. An adapter that declares one is non-conforming; report it rather than honoring it.

**What the bundles guarantee** on a conforming adapter's behalf — `gh-sdlc` relies on all six, and none of them are the adapter's to reimplement:

| Capability | Guaranteed by |
|---|---|
| **Pre-flight housekeeping** | `gh-dev-loop/PREFLIGHT.md` — assign the issue, Status → In Progress, branch `em/<issue#>_<task_slug>`, cascade the parent epic |
| **Test-approval gate** | `dev-loop/LOOP.md` — a per-task human gate (`shipit`) on the tests before implementation proceeds, distinct from the phase tokens in [GATES.md](./GATES.md) |
| **Atomic commits** | `dev-loop/LOOP.md` — smallest independently-green, independently-revertable units, single-line messages, tests shipped with their implementation |
| **Draft PR** | `gh-dev-loop/CLOSEOUT.md` — one task = one draft PR carrying `Closes #<issue>`, or the tracking-issue URL when the deliverable repo differs |
| **Review loop** | `gh-dev-loop/CLOSEOUT.md` — address automated/human review feedback before merge |
| **Close-out** | `gh-dev-loop/CLOSEOUT.md` — merge, Status → Done, and the epic cascade when the parent's last child closes |

**Conforming executors today:**

- **`ruby-dev`** — standalone Ruby (gems, CLIs, Rack/Sinatra). Not Rails.

### When a project has no conforming executor

Do not hand tasks to a mismatched loop, and do not merely stop. The halt has a prescribed remedy, because an adapter is cheap once the toolchain is decided:

1. **Design must fix the slots.** The Design phase produces an ADR naming the test runner, the linter, and the test-file convention. This is compelled anyway — [PLANNING.md](./PLANNING.md)'s pre-publish check forbids publishing a brief whose acceptance names a command the pointer cannot supply.
2. **Planning's first task authors the adapter.** The WBS opens with a `type:chore` task creating the adapter from that ADR, `addBlockedBy`-wired as a blocker of every other implementation task, so implementation cannot structurally begin without it.
3. **Then the pointer is updated** to name the new executor, and the project proceeds normally.

Adapters live in the shared skills tree, not in the project repo, so they stay reusable by any project in that language. **That makes the adapter task cross-repo, and it has a precondition:** the skills tree must itself be a git repo with a working remote, or the task cannot open a PR and there is nothing to review. Verify it before publishing the WBS (Planning's pre-publish deliverable-repo check), and if the tree has never been pushed, provision the remote first. The task's issue and board stay with the project; only the branch and PR live in the skills repo — see [PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md) → *When the deliverable lives in another repo*.

### Invariant — Planning must never contradict the pointer

> Task briefs **MUST NOT** hardcode any language's test command, lint command, or file layout. Every acceptance criterion is **derived from the resolved implementation-loop pointer** at Planning time. Where a phase file shows a concrete example, Ruby appears **only as a worked example, labelled as such.**

A brief whose acceptance says `bundle exec rspec` in a Node project is an unsatisfiable criterion and a direct contradiction of that project's executor. [PLANNING.md](./PLANNING.md) enforces this with a pre-publish check.

---

## Maintenance mode (post-v1)

Once a project has shipped, `/gh-sdlc` doubles as its maintenance router. Unlike the three phases, Maintenance is a **standing mode** with no single terminal token — load [MAINTENANCE.md](./MAINTENANCE.md) (with a Loaded-Files ACK) and run the requested verb:

| Verb | Does |
|---|---|
| `maintenance setup` | Idempotently put a shipped repo into maintenance mode: ensure the taxonomy labels, open the first/next `vX.Y` window milestone, and record a Maintenance pointer in `docs/project-workflow.md`. |
| `maintenance create <bug\|enhancement\|chore> <context>` | **Defaults to plan mode + `/grill-me`** to clarify and triage, drafts the issue brief, and only files it on approval — then routes it per the triage gate. |
| `maintenance close-window` | Close the current milestone, roll open survivors forward to the next window, open the next. |

**Scoped maintenance features.** When `maintenance create`'s triage gate marks an ask as needs-design, `/gh-sdlc` runs Discovery → Design → Planning **scoped to that single feature**, not the whole project. The substrate is already bootstrapped (`docs/project-workflow.md` exists), so it skips [SUBSTRATE.md](./SUBSTRATE.md) and goes straight to the relevant phase; the resulting epic + tasks all carry the active window milestone.

The model, taxonomy, triage table, and command procedures live in [MAINTENANCE.md](./MAINTENANCE.md); per-project specifics (milestone naming, field IDs) live in each project's `docs/project-workflow.md`.

---

## Compliance rules

- **Loaded-Files ACK** after every reference-file read.
- **No bulk loads** — one phase file at a time.
- **No gate skipping** — every phase ends at its hard-stop; never advance without the exact token.
- **Smallest atomic chunks** — every artifact (question, ADR, task) is the smallest independently-reviewable unit; when in doubt, split.
- **Delegate, don't reinvent** — call the existing skills by name for the work they already own.
- **Single-line commits only** — matching the implementation loop and the user's commit rule.
- **Resolve the pointer, never assume it** — no task brief may name a test/lint command the project's executor does not own.
- **Ask if a path is missing** rather than guessing.
