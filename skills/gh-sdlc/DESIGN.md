# Design

**Input:** merged Discovery findings (`docs/discovery/<topic>.md` + resolved questions).
**Output:** locked technical decisions as ADRs in `docs/adr/` + `CONTEXT.md` glossary updates, solution diagrams, and a generic WBS skeleton.
**Hard-stop:** the design artifacts land as a **PR** the user reviews/merges, gated by the `design-approved` token (see [GATES.md](./GATES.md)).

Goal of the phase: navigate the solution design — lock the technical decisions, draw the shape of the solution, and sketch the work — without yet creating any implementation issues.

## 1. Lock decisions (delegate to `grill-with-docs`)

Run `grill-with-docs` against the Discovery findings. It owns the mechanics; honor them:

- **ADRs** in `docs/adr/` using its [ADR-FORMAT.md](../grill-with-docs/ADR-FORMAT.md) — sequential `NNNN-slug.md`, created lazily, one paragraph is fine. Only offer an ADR when the decision is **hard to reverse**, **surprising without context**, and **the result of a real trade-off**.
- **`CONTEXT.md`** glossary updates using its [CONTEXT-FORMAT.md](../grill-with-docs/CONTEXT-FORMAT.md) — sharpen fuzzy/overloaded terms, flag conflicts, keep it a glossary (no implementation detail).

These are the "technical decisions locked somewhere" — versioned in the repo, reviewable in the PR. **One decision per ADR, one concern per diagram** (the atomicity directive — see [SKILL.md](./SKILL.md)): split a sprawling decision into separate ADRs rather than writing one omnibus record.

### Observability is a first-class design concern

When the system does meaningful I/O — external calls, concurrency, long-running flows, error handling — **how it will be observed is a design decision, not an implementation afterthought.** Surface it during this phase and, when it clears the bar, capture it as its own ADR. The injected-diagnostic-logger pattern (a `telemetry:` seam defaulting to a `NullLogger`, with pluggable `scrub` + `correlation_tags`, separate from the human-output channel) is a textbook ADR candidate: it is **hard to reverse** (every orchestrator's signature carries the seam), **surprising without context** (a future reader wonders why logging is injected rather than a global), and **the result of a real trade-off** (injected DI vs. mixin vs. a global logger). Read the executor's observability guidance for the full contract (for a Ruby project, the bundled `ruby-dev/observability-guidelines.md` and its Rails vs. standalone adapters), then record the project's choice as an ADR and add the resulting vocabulary (diagnostic log, telemetry channel, `run_id`, scrub/correlation seams) to `CONTEXT.md`.

## 2. Diagram the solution (Miro-primary)

Diagrams are **Miro-primary**: build malleable boxes and arrows on a Miro board and iterate there until the shape settles — that's where the thinking happens. Then **lock** the settled board into a versioned `docs/` artifact.

Use the Miro MCP (`plugin-miro-miro`); read the `miro-mcp` skill before driving it if you haven't. Typical flow:

1. Create or reuse a board for this project; add shapes/connectors for the components, boundaries, and data flows implied by the ADRs.
2. Iterate live with the user — move boxes, re-route arrows, rename — until they're happy.
3. **Lock step** — export the settled board to a versioned artifact under `docs/`:
   - **mermaid translation** embedded in the relevant ADR (preferred when the diagram is a clean flow/sequence/ER that mermaid expresses faithfully), **or**
   - **screenshot** image saved under `docs/design/<topic>.png` and linked from the ADR (preferred when the Miro layout carries meaning mermaid would flatten — spatial grouping, swimlanes, annotations).
   - Always link the **live Miro board URL** from the ADR so the malleable source stays discoverable.

### Fallback — mermaid-only

If the Miro MCP is unavailable, or the project is too small to justify a board, skip Miro entirely and author the diagram directly as mermaid embedded in the ADR. The versioned `docs/` artifact is the only hard requirement; Miro is the preferred authoring surface, not a gate.

## 3. Sketch the WBS skeleton (no issues yet)

Produce a **generic work-breakdown skeleton** — the epic/task outline Planning will turn into real issues. This is prose in the design artifact, not `gh issue create` calls. For each prospective epic note its area, the tasks beneath it, rough size, and the cross-epic dependencies the diagrams revealed. This is the bridge into Planning; keep it coarse.

## 4. Track the design work (optional epic)

If the design itself is substantial, create one **Design epic** (`type:epic`, `phase:design`) with one sub-task per ADR/diagram so the work is visible on the board. For lightweight designs, a single PR is enough — don't manufacture tracking overhead.

## 5. Reach the hard-stop

Open a PR carrying the ADRs, `CONTEXT.md` updates, the locked diagram artifact(s), and the WBS skeleton (single-line commit, branch `em/<epic#>_design_<slug>`). Then run the **Design gate** in [GATES.md](./GATES.md): present the decisions + diagrams, ask for the `design-approved` token, and **do not start Planning** until it's given and the PR is merged. The merged PR is the durable record.
