# agent-skills

My agent skills, living in `~/.agents/skills/` where every coding agent on this
machine picks them up.

## What this repo tracks

Only skills I wrote. Third-party skills live in the same directory — that is how
agent discovery works — but are git-ignored by name and installed by the
`skills` CLI instead. So `git log` is mine, and taking an upstream update
produces no diff beyond `.skill-lock.json`.

See [docs/adr/0001](docs/adr/0001-track-only-first-party-skills.md) for the
reasoning.

## First-party skills

| Skill | Invoked | What it is |
|---|---|---|
| [`gh-sdlc`](skills/gh-sdlc/SKILL.md) | typed | A phased SDLC router on a GitHub substrate — Discovery, Design, Planning — with a mandatory human-approval hard-stop between every phase. Language-agnostic; per-task execution is handed to the project's implementation loop. |
| [`ruby-dev`](skills/ruby-dev/SKILL.md) | typed | The standalone-Ruby adapter for the shared dev loop. Gems, CLIs, Rack/Sinatra. Not Rails. |
| [`node-dev`](skills/node-dev/SKILL.md) | typed | The Node adapter for the shared dev loop. Scripts, CLIs, small services. |
| [`dev-loop`](skills/dev-loop/LOOP.md) | bundle | The substrate-free per-task loop: plan the commits, write failing tests, stop at the `shipit` gate, implement, refactor, commit atomically. Plus portable view-layer conventions in `UI.md`. |
| [`gh-dev-loop`](skills/gh-dev-loop/PREFLIGHT.md) | bundle | The GitHub-substrate ends of that loop: issue routing and board housekeeping before, PR and close-out after. |

`dev-loop` and `gh-dev-loop` have no `SKILL.md` on purpose. They are shared
bundles loaded by relative path from a language adapter, never invoked
directly, so they stay invisible to skill discovery.

An adapter is conforming when it declares the nine language slots and loads all
three shared stage files — see the executor contract in
[`gh-sdlc/SKILL.md`](skills/gh-sdlc/SKILL.md).

## Third-party dependencies

Restore all of these with `./bootstrap.sh`.

### Required

`gh-sdlc` calls these two by name via the Skill tool. Without them it degrades.

| Skill | Source | Why |
|---|---|---|
| `grilling` | mattpocock/skills | The interview primitive behind Discovery question elicitation and `maintenance create`. |
| `domain-modeling` | mattpocock/skills | Keeps `CONTEXT.md` and ADRs current during the Design phase. |

### Typed

Nothing here depends on these; they are commands I reach for.

| Skill | Source | Why |
|---|---|---|
| `grill-me` | mattpocock/skills | Stress-test a plan. A shim over `grilling`. |
| `grill-with-docs` | mattpocock/skills | Same, plus doc-building. A shim over `grilling` and `domain-modeling`. |
| `handoff` | mattpocock/skills | Compact a conversation so another agent can continue it. |
| `improve-codebase-architecture` | mattpocock/skills | Survey a codebase for deepening opportunities. |
| `prototype` | mattpocock/skills | Throwaway prototype to answer a design question. |
| `writing-for-agents` | mattpocock/skills | Writing skills and agent-facing docs. Replaces the retired `write-a-skill`. |
| `codebase-design` | mattpocock/skills | Architecture vocabulary. Pulled in by `improve-codebase-architecture`. |
| `find-skills` | vercel-labs/skills | Discover and install skills. |

The set is deliberately small, and the exclusions are load-bearing — `tdd` in
particular is model-invoked and would compete with the `shipit` gate in
`dev-loop/LOOP.md`. See
[docs/adr/0004](docs/adr/0004-curated-third-party-skill-set.md).

## Setup on a new machine

```bash
git clone git@github.com:efmcuiti/agent-skills.git ~/.agents
cd ~/.agents && ./bootstrap.sh
```

`bootstrap.sh` installs for `codex` and `cursor` by default; override with
`SKILLS_AGENTS="codex cursor warp" ./bootstrap.sh`.

A script is needed because `.skill-lock.json` is a receipt, not a manifest — the
CLI has `add`, `remove`, `update`, and `list`, but nothing that reinstalls from
it.

## Updating third-party skills

```bash
npx skills@latest update -g
npx skills@latest list -g
```

Upstream renames and deletes skills, so `update` alone will not catch
everything. When a skill disappears, remove it and add its replacement by hand,
then update `bootstrap.sh` and the tables above.

Before taking an update, check whether anything in `skills/gh-sdlc/` references
a skill that moved:

```bash
rg -n 'Skill tool with' skills/gh-sdlc
rg -n '\]\(\.\./' skills/gh-sdlc   # should only ever point at dev-loop or gh-dev-loop
```

## Decisions

- [0001](docs/adr/0001-track-only-first-party-skills.md) — track only first-party skills
- [0002](docs/adr/0002-delegate-to-model-invoked-primitives.md) — delegate to model-invoked primitives
- [0003](docs/adr/0003-vendor-the-doc-format-files.md) — vendor the two doc-format files
- [0004](docs/adr/0004-curated-third-party-skill-set.md) — curate the third-party set

Two files under `skills/gh-sdlc/` are copied from mattpocock/skills under MIT.
See [NOTICE](NOTICE).
