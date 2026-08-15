# gh-sdlc delegates to model-invoked primitives, not user-invoked skills

`gh-sdlc` used to delegate to `grill-me` and `grill-with-docs` by name. Upstream has since reduced both to shims — `grill-me` is now seven lines whose entire body is "Call the Skill tool with 'grilling'", and `grill-with-docs` calls `grilling` and `domain-modeling`. Delegating to a shim means depending on two skills to reach one, and it breaks outright if the shim is installed without its primitive.

`gh-sdlc` now calls `grilling` and `domain-modeling` directly via the Skill tool.

## Considered Options

**Keep the shims and install all four.** Rejected: two files whose entire content is a redirect, for no benefit.

**Pin `grill-me` and `grill-with-docs` at their old self-contained versions.** Rejected: it freezes two skills forever and forfeits improvements to the interview technique itself, which is the part I actually use.

## Consequences

This also resolves a latent violation of upstream's own invocation rule — *a user-invoked skill may invoke model-invoked skills, but never another user-invoked one*. `gh-sdlc` sets `disable-model-invocation: true`, and so do `grill-me` and `grill-with-docs`, so the old edges pointed user-invoked at user-invoked. The new ones point at model-invoked primitives, which is the sanctioned direction.

`grill-me` and `grill-with-docs` stay installed, but as commands I type — nothing in this tree depends on them any more.
