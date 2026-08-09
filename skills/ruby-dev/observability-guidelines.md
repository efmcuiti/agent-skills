# Observability Guidelines

Structured, machine-readable diagnostic logging for Ruby projects — standalone CLIs **and** server-based Rails apps. The same vocabulary (`rich_log` / `log_tags` / levels / `scrub` / `correlation_tags`) works in both; only the *adapters* (sink + correlation + integration mode) differ by environment.

This is the portable descendant of negotiatus' `app/helpers/logging_helper.rb`. Where that helper hard-codes `Rails.logger` and Datadog, this guideline pulls both behind seams so the pattern degrades gracefully in a no-Rails, no-Datadog CLI.

---

## What this is for

A **diagnostic log** is a stream of structured JSON-line events for *after-the-fact analysis* — failures, long-running flows, concurrency, external calls. It is **not** the user-facing output.

- **Off by default** in standalone projects — a `NullLogger` no-ops every call until explicitly enabled.
- **Machine-facing** — one JSON object per line, consistent messages with variable data in tags, so logs aggregate and query cleanly.
- **Separate from human output** — the human-progress channel (`CliPrompt`, `puts`, flash messages) and the diagnostic-event channel are two distinct seams. **Never merge them.**

---

## The contract (environment-agnostic)

A base `StructuredLogger` exposes one public method, `rich_log`, plus the overridable `log_tags` hook. Everything else is a private seam with a sensible default.

```ruby
class StructuredLogger
  VALID_LEVELS = %i[debug info warn error fatal].freeze

  # message: a CONSTANT string; put variable data in tags.
  def rich_log(message:, tags: {}, level: :info)
    all_tags = scrub(default_tags.merge(tags))
    payload  = { message: scrub_message(message) }.merge(all_tags)
    emit(normalize_level(level), payload.to_json)
  end

  # Override per component to add sticky tags (the negotiatus hook).
  def log_tags
    {}
  end

  private

  # base_tags + log_tags. base_tags carries identity + correlation.
  def default_tags
    { caller: component_name }.merge(correlation_tags).merge(log_tags)
  end

  # SEAM: empty by default. Standalone -> { run_id: }. Rails+Datadog -> { dd: {...} }.
  def correlation_tags
    {}
  end

  # SEAM: identity by default. slack-status-cli -> SecretScrubber. Rails -> own filter.
  def scrub(tags)        = tags
  def scrub_message(msg) = msg

  # SEAM: where the JSON line goes. Standalone -> an IO. Rails -> Rails.logger.
  def emit(level, json)
    raise NotImplementedError
  end

  def component_name
    is_a?(Class) ? name : self.class.name
  end

  def normalize_level(level)
    return :info if level.nil?
    sym = level.to_sym
    VALID_LEVELS.include?(sym) ? sym : :info
  end
end
```

Key invariants, regardless of environment:

- **`rich_log(message:, tags:, level:)`** is the only entry point. Invalid levels fall back to `:info`.
- **`log_tags`** holds the tags that should appear on *every* line for a component (primary entity IDs, `run_id`, etc.). Override it; don't repeat those tags at each call site.
- **`scrub` is mandatory where secrets exist.** Both the message and the tag values pass through it before emit. In slack-status-cli the rule is absolute — *never log a secret value* — so the scrub seam wires `SlackStatusCli::SecretScrubber`.
- **`NullLogger`** implements the same surface with a no-op `rich_log`. It is the off switch and the safe default for any optional `telemetry:` argument.

```ruby
class NullLogger < StructuredLogger
  def rich_log(message:, tags: {}, level: :info) = nil
end
```

---

## Integration: injected vs mixin

Two integration modes share the contract above. Pick by environment.

### Injected collaborator (preferred for standalone Callable pods)

Pure queries/commands stay logger-free. Orchestrators take a `telemetry:` keyword defaulting to `NullLogger`, and the composition root decides whether to inject a real logger.

```ruby
class EmojiMigration::Commands::Run
  extend Callable

  def initialize(emoji_map:, out_dir:, telemetry: NullLogger.new)
    @emoji_map = emoji_map
    @out_dir = out_dir
    @telemetry = telemetry
  end

  def call
    telemetry.rich_log(message: "emoji export started", tags: { count: emoji_map.size })
    # ...
  end

  private

  attr_reader :emoji_map, :out_dir, :telemetry
end
```

Benefits: a real `NullLogger` off-switch, trivial assertion in specs (a `CapturingLogger` fake), and no cross-cutting concern bolted onto every callable.

### Mixin (Rails-idiomatic — negotiatus' exact form)

In Rails services, `include` the module and override `log_tags`; `caller` is derived from `self.class.name`.

```ruby
class Invoices::Commands::MarkPaid
  include LoggingHelper   # provides rich_log + log_tags + base tags

  def call
    rich_log(message: "invoice marked paid", tags: { amount_cents: invoice.amount_cents })
  end

  private

  def log_tags = { invoice_id: invoice.id, organization_id: invoice.organization_id }
end
```

Both modes speak the identical `rich_log`/`log_tags`/levels/scrub/correlation vocabulary, so moving a pattern between a CLI and a Rails app is a re-wiring, not a rewrite.

---

## Adapters by environment

### Standalone (CLI / gem)

- **Sink:** an injected `IO`, default `$stderr` — keeps `$stdout` clean for human output and piping.
- **Correlation:** a per-invocation `run_id` (`SecureRandom.hex`) created once at the composition root and carried via `correlation_tags`, so concurrent work (e.g. threaded downloads) and multi-step flows share one id.
- **Enablement:** the composition root reads an env var — e.g. `SLACK_STATUS_LOG` (unset/`off` -> `NullLogger`; `json` or a level -> real `StructuredLogger`). Off by default.
- **Scrub:** wire the project's secret scrubber (slack-status-cli: `SecretScrubber`).

```ruby
telemetry =
  case ENV["SLACK_STATUS_LOG"]
  when nil, "", "off" then NullLogger.new
  else StructuredLogger.new(io: $stderr, run_id: SecureRandom.hex(8))
  end
```

### Rails (server)

- **Sink:** `Rails.logger` (level honored by Rails config).
- **Correlation:** when Datadog tracing is active, add `dd: { trace_id, span_id }` for log-to-trace correlation — guarded by `defined?(Datadog::Tracing)` so it is a no-op without Datadog.
- **Enablement:** always constructed (no Null default needed); `:debug` is filtered out in production by `config.log_level`.
- **Scrub:** the app's own parameter filtering / redaction.

```ruby
def correlation_tags
  return {} unless defined?(Datadog::Tracing) && Datadog::Tracing.respond_to?(:correlation)
  c = Datadog::Tracing.correlation
  c.trace_id.to_i > 0 ? { dd: { trace_id: c.trace_id.to_s, span_id: c.span_id.to_s } } : {}
end
```

---

## Best practices (carried over from negotiatus)

### Consistent messages, variable data in tags

```ruby
# Good — stable message, variable data in tags (aggregates + alerts cleanly)
rich_log(message: "emoji download failed", level: :error, tags: { name: name, reason: e.message })

# Bad — interpolation makes logs unsearchable
rich_log(message: "emoji #{name} failed: #{e.message}")
```

### Log IDs, especially on `warn`/`error`

A failure line that omits the entity IDs forces a manual hunt. Put primary IDs in `log_tags` (every line) and operation-specific IDs at the call site. Prefer IDs over counts — counts lose the audit trail.

### Never log secrets

Tokens, passwords, personal data must never reach a log line. The `scrub` seam is the enforcement point in projects that have secrets; do not bypass it by string-building a payload yourself.

### What not to log

- String interpolation in messages (use tags).
- Sensitive values (rely on `scrub`).
- Large payloads — truncate or summarize.
- Noise — focus on business/operationally relevant events.

---

## The review gate

Telemetry is logic (level selection, tag shape, scrubbing, branching on success/failure), so it follows normal TDD — write a failing spec first. A `CapturingLogger` fake (records `rich_log` calls) is the cleanest collaborator for asserting *what* was logged without touching real IO. Pure-presentation carve-outs do not apply here.
