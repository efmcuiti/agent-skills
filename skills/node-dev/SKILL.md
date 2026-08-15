---
name: node-dev
description: "Test-first development workflow for Node.js projects (scripts, CLIs, small services) with a mandatory human review gate. Use when implementing features, fixing bugs, or making any code changes in a personal Node project. Enforces TDD with explicit human approval before implementation, GitHub Issue routing, and atomic commits."
disable-model-invocation: true
---

# Node Dev

**The Node.js adapter for the shared development loop.** The lifecycle — GitHub pre-flight, the TDD cycle, the review gate, atomic commits, PR and close-out — lives in the `gh-dev-loop` and `dev-loop` bundles; this file supplies the Node slots those bundles read. Targets scripts, CLIs, and small Node services. Content-first projects (JSON/data + thin scripts) are first-class.

**This skill is opt-in.** Invoke it explicitly as `/node-dev`. It is never auto-applied.

**Approval token (exact):** `shipit`. **No implementation before `shipit`** — if you produce implementation before the gate, undo it and return to the gate. The gate is defined in `dev-loop/LOOP.md` and this adapter cannot weaken it.

**Loaded-Files ACK (after any load):**

```
ACK:
- Loaded: <list exact files just read>
- Next to load: <list exact files + why they are relevant>
- Slot sources: <adapter default | project override>, per slot used
```

Never bulk-load. If a required path is missing or unclear, **ask** rather than skipping.

**When to use:** implementing any feature, fix, or refactor in a personal Node project; moving from investigation to code; writing tests; or proposing solutions after analysis. Later-in-thread implementation requires the same rigor as at the start.

## Loading table

| File | When to load |
| ---- | ------------ |
| [../gh-dev-loop/PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md) | **Always at task start** — issue routing, next-workable-item, housekeeping, epic cascade |
| [../dev-loop/LOOP.md](../dev-loop/LOOP.md) | **Always** — steps 0-10, the `shipit` gate, review package, atomic commits |
| [../gh-dev-loop/CLOSEOUT.md](../gh-dev-loop/CLOSEOUT.md) | When shipping — draft PR, review loop, merge, board sync |
| `docs/project-workflow.md` (in the repo) | **Always during pre-flight** — project facts, field IDs, review recipes |
| `docs/architecture.md` (in the repo) | **Always when writing tests for any module** — authoritative when present |
| [../dev-loop/UI.md](../dev-loop/UI.md) | Task touches views, templates, or styles — flat BEM, CSS vars, semantic + accessible HTML |

When the repo has no `docs/architecture.md`, the **Doctrine: architecture conventions** section below is the fallback baseline.

## Language slots

Project values in the repo's `docs/project-workflow.md` **override** these defaults; for linting the probe is the final arbiter at run time. Name the source you used in your ACK.

| Slot | Value |
| ---- | ----- |
| Single-path test command | `node --test <path>` |
| Full-suite test command | `node --test` |
| Lint probe | `echo skip` |
| Lint autocorrect and check | not applicable until a project configures a linter |
| Dependency repair | `npm ci` |
| Test-file convention | `*.test.js` beside the unit under test (`test/*.test.js` when scripts sit at repo root) |

A project linter is **optional**: if the probe says `skip`, note it in one line ("linter not configured in this project — skipping lint") and never fail the cycle over it. Projects that adopt ESLint/Biome override the lint slots in `docs/project-workflow.md`.

## Doctrine: test-authoring idiom

| Avoid | Prefer |
| ----- | ------ |
| Jest / Vitest by default | `node:test` + `node:assert/strict` |
| Loose `node:assert` equality | `import assert from "node:assert/strict"` |
| Mocking frameworks / auto-mocks | Injected purpose-built fakes (plain objects or tiny classes) |
| Stubbing `fs` / `fetch` / `child_process` globally | Pass collaborators in; hand the test a fake |
| FactoryBot-style factories | Small builder helpers next to the suite or under `test/support/` |
| Real network in unit tests | Injected client / `MockAgent`; keep net off the unit path |

Use `describe` / `it` (or `test`) from `node:test`. Reach for `mock.fn` / `mock.method` only at I/O boundaries, and restore mocks in `afterEach`. Prefer observable behavior over call-count assertions on internal collaborators.

## Doctrine: architecture conventions

Check before every commit — most are encapsulation rules no linter catches. The repo's `docs/architecture.md` is authoritative when it exists; otherwise this section applies.

- Keep scripts and modules **thin** until a helper earns extraction; content-first projects treat data files as the product and JS as glue.
- Inject collaborators (fs, HTTP, shell, clock) rather than hardcoding imports of side-effecting APIs inside pure logic.
- Raise from module-local `Error` subclasses (`class NotFoundError extends Error`), not bare strings or untyped `Error` throws at call sites.
- Import builtins with the `node:` protocol (`node:fs`, `node:path`, `node:test`).
- Telemetry is an injected collaborator defaulting to a no-op logger; pure queries and transforms stay logger-free.

## Doctrine: style and outline vocabulary

- **Use double-quoted strings** in greenfield JS — this holds whether or not a linter runs.
- The Test-Only Review Package presents a **`describe` / `it` outline** via `node:test`.
- Assert with **`node:assert/strict`**; unexpected green means tighten expectations until red.
- Telemetry is logic and ships test-first, with a capturing fake asserting what was logged.

## Compliance

- **Loaded-Files ACK** after every load; no bulk loads; ask if a path is missing.
- **No implementation before `shipit`** — undo and return to the gate if violated.
- **Unexpected green** — tighten tests until red.
- **Never commit a test without its implementation**, or implementation without its test.
- **Single-line commit messages only.**
- **Stay focused** — collect unrelated issues and surface them at Step 10 only.
