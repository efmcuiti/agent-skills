# Vendor ADR-FORMAT.md and CONTEXT-FORMAT.md into gh-sdlc

`gh-sdlc/DESIGN.md` linked to `../grill-with-docs/ADR-FORMAT.md` and `../grill-with-docs/CONTEXT-FORMAT.md`. Upstream moved both files into a new `domain-modeling/` skill, leaving `grill-with-docs/` with nothing but a `SKILL.md` — so taking the update broke both links. Copies now live in `skills/gh-sdlc/` and the links point at `./`.

The distinction that settled it: delegating by **skill name** is robust, because a name is a public interface that survives reorganisation. Delegating by **relative file path** reaches into another skill's internal layout, which is nobody's contract and moved twice in three months.

## Considered Options

**Repoint at `../domain-modeling/ADR-FORMAT.md`.** Preserves delegate-don't-duplicate exactly and stays current. Rejected because it re-breaks the next time upstream reorganises, and it makes `domain-modeling`'s *file layout* — not just its name — a hard dependency.

**Fold both formats into `DESIGN.md` as prose.** Rejected: `DESIGN.md` is already long, and the formats are referenced as standalone documents.

## Consequences

Two MIT-licensed documents are now mine to maintain and will drift from upstream. That is acceptable: both are static convention documents with no logic (48 and 64 lines), and `DESIGN.md` had already partly forked one by restating its "hard to reverse, surprising, real trade-off" rule inline.

This is a deliberate exception to `gh-sdlc`'s "delegate, don't reinvent" rule, not an oversight. Do not "fix" it by re-pointing the links at whichever skill currently holds these files. See `NOTICE` for attribution.
