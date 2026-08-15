# Install a curated subset of mattpocock/skills, not the whole set

Upstream ships around two dozen skills and grows steadily. We install nine, on two grounds only: what this tree hard-depends on (`grilling`, `domain-modeling`, and `codebase-design` via `improve-codebase-architecture`), and what I actually type (`grill-me`, `grill-with-docs`, `handoff`, `improve-codebase-architecture`, `prototype`, `writing-for-agents`).

## Considered Options

**Install everything and let `ask-matt` route.** Rejected — see the consequence below; the conflict is not hypothetical.

**Take only `grilling` and `domain-modeling`.** Maximum isolation, but it costs `/grill-me` and `/handoff` as typed commands for no real gain, since user-invoked skills only run when I ask for them.

## Consequences

The refusals matter more than the selections. `tdd` is **model-invoked**, so an agent can reach for it unprompted mid-session and apply a discipline that competes with the `shipit` gate in `dev-loop/LOOP.md`. Its absence is load-bearing, not an oversight.

`implement`, `triage`, `to-tickets`, `to-spec`, and `code-review` are excluded on the same reasoning at a higher level: `gh-sdlc` plus `dev-loop`/`gh-dev-loop` plus the language adapters already own the lifecycle from discovery through close-out, more specifically than a general-purpose suite can. `setup-matt-pocock-skills` is excluded because `gh-sdlc/SUBSTRATE.md` provisions the GitHub labels, fields, and Projects v2 board itself.

Anything added later should have to answer the same two questions: does something here depend on it, or will I type it?
