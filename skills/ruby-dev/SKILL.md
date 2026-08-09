---
name: ruby-dev
description: "Test-first development workflow for standalone Ruby projects (gems, CLIs) with a mandatory human review gate. Use when implementing features, fixing bugs, or making any code changes in a personal Ruby project. Enforces TDD with explicit human approval before implementation, GitHub Issue routing, and atomic commits."
disable-model-invocation: true
---

# Ruby Dev

**The standalone-Ruby adapter for the shared development loop.** The lifecycle — GitHub pre-flight, the TDD cycle, the review gate, atomic commits, PR and close-out — lives in the `gh-dev-loop` and `dev-loop` bundles; this file supplies the Ruby slots those bundles read. Targets gems, CLIs, and Rack/Sinatra apps. **Not Rails** — see [rails-notes.md](./rails-notes.md).

**This skill is opt-in.** Invoke it explicitly as `/ruby-dev`. It is never auto-applied.

**Approval token (exact):** `shipit`. **No implementation before `shipit`** — if you produce implementation before the gate, undo it and return to the gate. The gate is defined in `dev-loop/LOOP.md` and this adapter cannot weaken it.

**Loaded-Files ACK (after any load):**

```
ACK:
- Loaded: <list exact files just read>
- Next to load: <list exact files + why they are relevant>
- Slot sources: <adapter default | project override>, per slot used
```

Never bulk-load. If a required path is missing or unclear, **ask** rather than skipping.

**When to use:** implementing any feature, fix, or refactor in a personal Ruby project; moving from investigation to code; writing tests; or proposing solutions after analysis. Later-in-thread implementation requires the same rigor as at the start.

## Loading table

| File | When to load |
| ---- | ------------ |
| [../gh-dev-loop/PREFLIGHT.md](../gh-dev-loop/PREFLIGHT.md) | **Always at task start** — issue routing, next-workable-item, housekeeping, epic cascade |
| [../dev-loop/LOOP.md](../dev-loop/LOOP.md) | **Always** — steps 0-10, the `shipit` gate, review package, atomic commits |
| [../gh-dev-loop/CLOSEOUT.md](../gh-dev-loop/CLOSEOUT.md) | When shipping — draft PR, review loop, merge, board sync |
| `docs/project-workflow.md` (in the repo) | **Always during pre-flight** — project facts, field IDs, review recipes |
| `docs/architecture.md` (in the repo) | **Always when writing tests for any class** — authoritative when present |
| [architecture-primer.md](./architecture-primer.md) | Writing tests for a class **and** the repo has no `docs/architecture.md` — fallback baseline |
| [../dev-loop/UI.md](../dev-loop/UI.md) | Task touches views, templates, or styles — flat BEM, CSS vars, semantic + accessible HTML |
| [ui-guidelines.md](./ui-guidelines.md) | Same trigger — the Ruby delta (ERB comments, `rackup` preview) |
| [observability-guidelines.md](./observability-guidelines.md) | Task touches a service, command, or orchestrator doing I/O, external calls, concurrency, or error handling |
| [rails-notes.md](./rails-notes.md) | **Never** — parked reference, not doctrine |

## Language slots

Project values in the repo's `docs/project-workflow.md` **override** these defaults; for linting the probe is the final arbiter at run time. Name the source you used in your ACK.

| Slot | Value |
| ---- | ----- |
| Single-path test command | `bundle exec rspec <path> --format documentation` |
| Full-suite test command | `bundle exec rspec` |
| Lint probe | `bundle exec rubocop --version >/dev/null 2>&1 && echo runnable \|\| echo skip` |
| Lint autocorrect and check | `bundle exec rubocop --autocorrect <changed .rb files>` then `bundle exec rubocop <changed .rb files>` |
| Dependency repair | `bundle install` |
| Test-file convention | `spec/` mirrors the full `lib/` path, `_spec.rb` suffix: `lib/<project>/<pod>/queries/resolve_token.rb` → `spec/<project>/<pod>/queries/resolve_token_spec.rb` — no flattening |

Rubocop is **optional** in these projects: if the probe says `skip`, note it in one line ("Rubocop not configured in this project — skipping lint") and never fail the cycle over it.

## Doctrine: test-authoring idiom

Standalone Ruby replaces the Rails/pi-pod equivalents:

| Rails / pi-pod | ruby-dev equivalent |
| -------------- | ------------------- |
| FactoryBot `create`/`build` | Plain Ruby builder helpers in `spec/support/` (e.g. `build_token_response`) |
| RSpec doubles for collaborators | Real fake classes preferred (e.g. `FakeShellRunner`, `FakeKeychain`) |
| `LoggingHelper` / `rich_log` | `puts` / `warn` / `CliPrompt` |
| VCR / WebMock cassettes | `stub_request` with inline response hashes; `WebMock.disable_net_connect!` in `spec_helper` |
| Global Open3/shell stubs | Injected fake collaborators — never stub `Open3` globally |
| `app/services/foo.rb` | `lib/<project>/<pod>/foo.rb` |

**Not ported from pi-pod:** Pundit, the FactoryBot gem, Strong Migrations, ActiveRecord, `LoggingHelper`, ViewComponents, Stimulus, Turbo.

## Doctrine: architecture conventions

Check before every commit — most are encapsulation rules no Rubocop catches, so they are easy to drift on. The repo's `docs/architecture.md` is authoritative when it exists; otherwise [architecture-primer.md](./architecture-primer.md) applies.

- Constructor params exposed via a `private attr_reader` and read through the readers; **never** touch a raw `@ivar` outside `initialize`.
- `extend Callable` with explicit `*args/**kwargs/&block` forwarding, not a block-dropping `new(...).call`.
- Each pod raises from its own `Errors` module (`Error < StandardError` plus subclasses), not bare `RuntimeError`.
- Top-level stdlib constants `::`-qualified inside a namespaced pod (`::File`, `::Net::HTTP`).
- String and regexp constants frozen.
- Telemetry is an injected collaborator defaulting to `NullLogger`; pure queries and commands stay logger-free.

## Doctrine: style and outline vocabulary

- **Use double-quoted strings** in all Ruby code — this holds whether or not Rubocop runs.
- The Test-Only Review Package presents an **RSpec outline**: bulleted `describe` / `context` / `it`.
- Telemetry is logic and ships test-first, with a `CapturingLogger` fake asserting what was logged.

## Compliance

- **Loaded-Files ACK** after every load; no bulk loads; ask if a path is missing.
- **No implementation before `shipit`** — undo and return to the gate if violated.
- **Unexpected green** — tighten tests until red.
- **Never commit a spec without its implementation**, or implementation without its spec.
- **Single-line commit messages only.**
- **Stay focused** — collect unrelated issues and surface them at Step 10 only.
