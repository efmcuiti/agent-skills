# Architecture Primer

A compact, project-agnostic baseline for structuring personal Ruby projects — the Callable/Query/Command split, pod layout with spec mirroring, and `docs/` conventions.

> **Fallback only.** This primer applies when a project has **no** `docs/architecture.md` of its own. When a project ships one (as slack-status-cli does), that per-project doc is the source of truth and wins on any conflict — load it instead.

---

## Callable / Query / Command

Business logic lives in small, single-purpose **Callable** objects rather than fat models or controllers. Each exposes one class method, `.call(...)`, and nothing else public.

- **Callable base** — a tiny module that provides the `.call` class method delegating to a per-instance `#call`. Every unit of logic `extend`s it.
- **Query** — reads and returns a value; no side effects. Naming reads as a noun-ish answer (`ResolveToken`, `MergedSettings`, `Standings`).
- **Command** — performs a side effect (writes a file, calls an API, mutates state). Naming reads as an imperative verb (`PersistToken`, `PostStatus`).

```ruby
module Callable
  # Forward positional/keyword args to the initializer AND the block to #call.
  # A bare `new(...).call` hands the block to `initialize` (which ignores it),
  # silently dropping it instead of letting the operation yield.
  def call(*args, **kwargs, &block)
    new(*args, **kwargs).call(&block)
  end
end

# Query: pure read, returns a value, no side effects
class ResolveToken
  extend Callable

  def initialize(profile:, cli_token:)
    @profile = profile
    @cli_token = cli_token
  end

  def call
    # walk a fixed precedence chain; first non-empty wins; no silent fallbacks
  end

  private

  attr_reader :profile, :cli_token
end
```

Keep the precedence/branching logic explicit and fail loudly (raise with remediation) rather than falling back silently.

### Callable conventions

Keep every callable shaped the same way:

- **`extend Callable`, not `include`.** The base defines an instance-style `call` that becomes the class method via `extend`, and it forwards the block explicitly (see above) — never the terser `new(...).call`, which drops the block.
- **Private `attr_reader` for constructor params.** `initialize` assigns each keyword to an `@ivar`; everything below reads through a `private attr_reader` rather than touching the raw `@ivar`. Inputs stay named, read-only, and trivially stubbable in specs.
- **Each pod owns its error vocabulary.** A pod defines its own `Errors` module with a base `Error < StandardError` plus specific subclasses (e.g. `Tokens::Errors::NotFound`), and raises those rather than a bare `RuntimeError`/`StandardError`. Callers rescue the pod's base `Error` to scope failure handling.
- **`::`-qualify top-level stdlib constants** inside a namespaced pod (`::File`, `::FileUtils`, `::Net::HTTP`) so a future same-named constant in the namespace can't shadow the standard library by accident.
- **Freeze string (and regexp) constants** (`FILENAME = "skipped.json".freeze`) so shared literals can't be mutated in place.
- **Never log secret values.** For tools that handle credentials, print the *source* of a resolved secret, not the value, and scrub `xox`-style (or equivalent) patterns out of any logged exception. A real secret in a log line is a bug.

---

## Pod layout & spec mirroring

Group Callables by domain into **pods** under `lib/<project>/<pod>/`, separating queries from commands:

```
lib/
├── <project>.rb                 # root namespace + autoload entry point
└── <project>/
    ├── callable.rb              # the Callable base
    ├── <pod>/
    │   ├── queries/
    │   │   └── resolve_token.rb
    │   └── commands/
    │       └── persist_token.rb
    └── <other_pod>/...
```

**Spec mirroring rule:** every `lib/` file maps to a spec at the same path under `spec/`:

```
lib/<project>/<pod>/queries/resolve_token.rb
→ spec/<project>/<pod>/queries/resolve_token_spec.rb
```

Mirror the full `lib/` path under `spec/` — no flattening into `spec/queries/`.

---

## `docs/` conventions

When a project grows its own `docs/`, keep it lightweight and self-describing:

- **Plain GitHub-rendered markdown** — no MkDocs/Docusaurus build step until the docs genuinely outgrow it (roughly ~15 files or diagrams needing a custom renderer).
- **Relative cross-links** (`[setup.md](setup.md)`, `[../lib/foo.rb](../lib/foo.rb)`) so the repo browses correctly both on GitHub and in a local clone.
- **Self-describing headers** — every `docs/*.md` opens with an H1 matching its README link text plus a one-sentence purpose blurb, so search results and section-loaders are immediately legible.
