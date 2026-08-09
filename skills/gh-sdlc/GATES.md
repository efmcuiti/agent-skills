# Gates — the phase hard-stops

Every phase ends at a mandatory human-approval hard-stop. The agent makes **no phase-advancing or issue-creating action** until the exact phase token is given. This mirrors the implementation loop's review-gate idiom, but with **distinct per-phase tokens** so a phase gate is never confused with the executor's in-implementation test-approval gate (`shipit` in `ruby-dev`).

## Tokens and artifacts

| Phase | Token (exact) | Durable artifact the user approves | Advancing this gate means |
|---|---|---|---|
| Discovery — Stage 1 | `discovery-approved` | the numbered **question proposal** (before any `gh issue create`) | file the Discovery epic + question issues, then **stop** |
| Discovery — Stage 2 | `findings-approved` | `docs/discovery/<topic>.md` **PR** (+ closed question issues) | start Design |
| Design | `design-approved` | ADRs + `CONTEXT.md` + locked diagram **PR** | start Planning |
| Planning | `plan-approved` | the numbered **WBS proposal** (before any `gh issue create`) | publish issues + hand off to the project's implementation loop |

Two shapes of gate, applied consistently:

- **Proposal gates** (`discovery-approved`, `plan-approved`) fire **before `gh issue create`**, because issue creation is the irreversible-ish action being gated. What the user approves is the proposal text.
- **PR gates** (`findings-approved`, `design-approved`) fire on a **PR** — the merged PR is the durable record, and merging is itself a GitHub-native review surface. The token unblocks the agent in-session; the merge is the artifact.

**Discovery has two tokens because it has two gated actions.** `discovery-approved` no longer approves the findings PR — it approves the *question set*, and the phase then hands back to the user to run the questions ([DISCOVERY.md](./DISCOVERY.md)). Only `findings-approved`, after every question is closed and consolidated, unlocks Design. Never treat `discovery-approved` as permission to start Design, and never resolve question issues in the same run that filed them.

## Gate protocol

When a phase reaches its boundary:

1. **Present the artifact.** Summarize what was produced and link it (PR URL, ADR paths, diagram artifact + Miro board, or the numbered WBS).
2. **Pose a single reflective prompt** (with an emoji) — confidence in the work plus a genuine question about the riskiest part of it. Vary tone and emoji each time; never repeat a prompt verbatim.
3. **Offer structured response options** via the `AskQuestion` tool. Options, in order:
   - **the phase token** (always first) — e.g. `discovery-approved` — approve and advance.
   - **1-2 context-specific revision options** — concrete gaps you suspect (e.g. "Reopen spike #14 — the fallback path is still unproven").
   - **Something else** (always last) — the user has different feedback; ask them to elaborate before acting.
4. **Honor the result.** Only the exact token advances the phase. Any other selection → address it and return to step 1. If the user picks "Something else", ask them to elaborate first.

### Example gate (Design)

```
🧭 The event-driven boundary between Orders and Billing feels right, and the ADR
captures why we rejected synchronous HTTP. The piece I'm least sure about is whether
the retry semantics belong in this ADR or their own — worth splitting?

1. design-approved — decisions + diagrams look good, start Planning
2. Split retry semantics into a second ADR before approving
3. Something else — I have different feedback
```

## Rules

- **No advance without the exact token.** Do not infer approval from "looks good" or a 👍 — require the literal phase token via the gate.
- **No pre-emptive work.** Do not create the next phase's epics, ADRs, or issues before its predecessor's gate has passed. No `gh issue create` until `discovery-approved` (Discovery) or `plan-approved` (Planning).
- **No filing-and-working in one breath.** After `discovery-approved` files the question issues, the run **ends**. Resolving them is a separate user-initiated `discovery run`.
- **One hard-stop minimum per phase.** A phase may pause for smaller confirmations, but it must always terminate at its token gate.
- **Tokens are phase-scoped.** The implementation loop's own test-approval gate (`shipit` in `ruby-dev`) belongs to per-task execution — never use it as a phase gate, and never use a phase token to approve tests.
