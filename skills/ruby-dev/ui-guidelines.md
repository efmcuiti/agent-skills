# Ruby view-layer delta

The Ruby-specific additions to the portable view conventions in [dev-loop/UI.md](../dev-loop/UI.md). Load **both** when a task touches views, templates, or styles: `UI.md` carries the flat-BEM, CSS-variable, semantic-HTML and accessibility doctrine, and this file adds the ERB and Rack specifics on top.

Applies to any Ruby project that renders HTML — Sinatra, Roda, Rack, or plain ERB.

---

## ERB comments for server-side notes, HTML comments only for shipped markup

`<!-- … -->` reaches the browser's view-source; `<% # … %>` does not. Use ERB comments for development notes, business-logic explanations, and anything that shouldn't reach end users. Reserve HTML comments for context that genuinely belongs in the rendered document.

```erb
<%# Server-side note — never shipped to the browser %>
<%# Scoring rules mirror lib/scoring.rb; keep in sync %>
```

The `UI.md` examples are written as plain HTML; in an ERB template the same markup carries `<%= %>` interpolation, and the inline-`style` rule applies unchanged — a dynamic value belongs in a CSS variable, not a raw property.

---

## Local preview for the presentational gate

The visual-verification checklist in [dev-loop/LOOP.md](../dev-loop/LOOP.md) allows an optional best-effort screenshot. For a Rack or Sinatra app, boot it with the project's run command — commonly:

```bash
bundle exec rackup
```

Then open the affected route and capture the states the checklist names. This is optional and non-blocking: if no preview is cheaply available, the written checklist stands on its own.

---

## Rails

This adapter targets **standalone Ruby** (gems, CLIs, Rack/Sinatra apps), not Rails. Rails view idioms are parked in [rails-notes.md](./rails-notes.md), which nothing loads; see that file's header for why.
