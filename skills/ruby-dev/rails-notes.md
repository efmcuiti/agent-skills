# Parked: Rails notes

**Nothing loads this file.** `ruby-dev` is the adapter for **standalone Ruby** — gems, CLIs, and Rack/Sinatra apps. It is not a Rails executor, and no loading table references this file.

It is kept because the notes below are the surviving residue of prior Rails work (pi-pod, negotiatus) and would be the starting point for a `rails-dev` sibling adapter if a Rails project ever appears. Until then it is documentation, not doctrine.

## Why Rails needs its own adapter rather than a flag on this one

Rails differs from standalone Ruby on both kinds of adapter slot, and only one kind can be rescued by a project override:

- **Mechanical slots** could be overridden per project in `docs/project-workflow.md` — the test-file convention would mirror `app/` as well as `lib/`, and dependency repair would add a test-database preparation step.
- **Doctrine sections are not project-overridable.** Rails wants FactoryBot instead of plain builders in `spec/support/`, brings ActiveRecord, Pundit and Strong Migrations into scope, uses ViewComponent/Stimulus/Turbo in the view layer, and prefers the mixin logging form over the injected telemetry seam.

Folding Rails into this adapter would therefore require making doctrine overridable, weakening the model for every other consumer. A sibling `rails-dev` adapter declaring its own slots against the same shared bundles is the cheaper answer.

## Rails view idioms (formerly the "Optional: Rails-only" section of ui-guidelines.md)

Short pointers, not a full port. The universal core in [dev-loop/UI.md](../dev-loop/UI.md) remains the base; these sit on top when the project is Rails.

- **ViewComponents + BEM helpers**: extract reusable UI into `ViewComponent::Base` subclasses with side-car `.css`; generate element classes with the BEM helpers (`block_class`) rather than hand-writing them.
- **Stimulus / Turbo**: use Stimulus controllers and Turbo Frames/Streams for dynamic behavior instead of jQuery/bespoke JS; lazy-load only truly non-critical frames.
- **`content_for :head`**: move view-specific `<style>` out of the body into the document head; wrap conditional styles in the same conditional.
- **Design-token systems (e.g. Zest)**: prefer an existing design system's tokens and components over hand-rolled CSS/glyphs when the project ships one. The universal "CSS variables as interface" pattern is the framework-agnostic version of the same idea.

> The original text deferred to a `/pi-dev` skill for the exhaustive treatment. **That skill is not installed**, so the reference is dropped rather than carried forward as a dangling link.

## Rails observability

The Rails adapter for structured logging is **not** parked here — it stays in [observability-guidelines.md](./observability-guidelines.md) on purpose. Having two environments (standalone CLI and Rails server) is what makes `emit`, `correlation_tags` and `scrub` genuine seams rather than over-engineering; deleting the Rails side would make the contract read as gratuitous indirection.
