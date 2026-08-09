# UI Guidelines

Portable view-layer conventions for any project that renders HTML and CSS — flat BEM, CSS variables as a component interface, and semantic, accessible markup. Language- and framework-neutral: the examples are plain HTML, and nothing here assumes a particular templating engine.

> **Loaded by a language adapter, on demand.** Load this when a task touches views, templates, or styles. Your adapter may also name a language-specific view delta (templating comment syntax, preview command, framework idioms) — load that alongside this file. Post a **Loaded-Files ACK** after reading.

The presentational review gate itself lives in [LOOP.md](./LOOP.md) — Step 2's carve-out and the visual-verification checklist. This file is the doctrine that checklist is checking against.

<!-- Section Index (for selective loading — read index, then load sections by line range)
| Section                              | Keywords                                                              |
| ------------------------------------ | --------------------------------------------------------------------- |
| Universal core                       | BEM, flat CSS, specificity, !important, --_ vars, inline styles       |
| Semantic HTML & accessibility        | heading hierarchy, aria-label, color contrast, visually-hidden        |
| Numeric columns                      | tabular-nums                                                          |
-->

The examples below are drawn from a real Sinatra + ERB + hand-rolled-CSS project. They are **illustrative patterns, not project-specific rules** — apply the same shapes to any view layer.

---

## Universal core

### Keep CSS flat with BEM naming

Nesting and descendant selectors raise specificity, which makes later overrides require hacks (or `!important`). Use flat [BEM](https://getbem.com/) class names that encode structure in the name instead of the selector tree.

A scoring panel is a good model — every element is a flat `block__element` class:

```css
/* Flat BEM — low, predictable specificity */
.scoring-panel { /* block */ }
.scoring-panel__title { /* element */ }
.scoring-panel__list { /* element */ }
.scoring-panel__note { /* element */ }
```

```css
/* Avoid — nesting and descendant selectors leak styles and raise specificity */
.scoring-panel {
  .scoring-panel__list {
    li { /* now hard to override from outside */ }
  }
}
```

Use modifiers (`block__element--variant`) for variants rather than overriding via context:

```css
.badge { /* base */ }
.badge--locked { /* variant */ }
.badge--pts { /* variant */ }
```

### Register a BEM element class instead of bare or descendant selectors

Styling a bare element (`button`, `a`) or a descendant (`.card a`) leaks onto every matching element inside the block and raises specificity. Give the element its own flat class and style that.

```css
/* Bad — leaks onto every <a> inside .topbar nav, and is hard to override */
.topbar nav a { color: var(--accent-2); }

/* Good — a named element class scoped to one role */
.topbar__nav-link { color: var(--accent-2); }
```

Pseudo-classes/elements and same-element state classes are the acceptable exceptions:

```css
.topbar__nav-link:hover { text-decoration: underline; }   /* pseudo-class */
.badge.is-locked { background: #3f3f46; }                  /* state on same element */
```

### Avoid `!important` on shared classes

`!important` forces the value on every consumer of a shared class; the only way to beat it later is another `!important`. If you reach for it to win a specificity battle, that's a signal the selectors are nested or too specific — flatten them instead. Use a modifier for the variant you actually want.

### Treat CSS variables as a component interface

Define a palette/tokens once (in a `:root` block), then let components consume them. For values a component repeats or wants to expose as a knob, use a **private local variable** prefixed `--_`, falling back to the shared token:

```css
/* Shared palette — define once */
:root {
  --bg: #0f172a;
  --panel: #1e293b;
  --accent: #22c55e;
  --border: #334155;
}

/* Component reads a private local that falls back to the palette */
.card {
  --_card-bg: var(--card-bg, var(--panel));
  --_card-border: var(--card-border, var(--border));
  background: var(--_card-bg);
  border: 1px solid var(--_card-border);
}

/* A variant overrides the semantic input, not the raw property */
.card--featured { --card-bg: var(--panel-2); }
```

The `--_` prefix signals "component-local/private"; the un-prefixed name (`--card-bg`) is the public input. This keeps components composable without descendant overrides.

Reach for a local variable whenever a rule repeats the same value (e.g. an icon's `width` and `height`) so there's a single source of truth:

```css
.flag { --_flag-size: 16px; width: var(--_flag-size); height: var(--_flag-size); }
```

### Keep styles out of inline `style` attributes

Inline `style="..."` can't be overridden by a stylesheet without `!important`, bypasses the palette/tokens, and scatters presentation across templates. Move the rule into a BEM class.

```html
<!-- Bad — bypasses the palette and the cascade -->
<div style="padding: 0.9rem; background: #1e293b; border-radius: 12px;">…</div>

<!-- Good — a class that reads tokens -->
<div class="card">…</div>
```

The one legitimate use is a genuinely *dynamic* value computed from data (e.g. a progress-bar width); even then, prefer setting a CSS variable inline over a raw property.

---

## Semantic HTML & accessibility

### Use semantic elements and a correct heading hierarchy

Choose elements by meaning, not appearance. Start at `<h1>` and never skip levels (`h1` → `h2` → `h3`). For purely visual emphasis with no document-structure meaning, use a `<div>`/`<span>` with a class instead of a heading tag.

```html
<!-- Leaderboard: h1 for the page, h2 for a subsection -->
<h1>Leaderboard</h1>
<h2>By round</h2>
```

Use `<header>`, `<main>`, `<nav>`, `<section>`, `<aside>`, and `<footer>` for their semantic roles rather than generic `<div>`s where a landmark fits.

### Never signal status by color alone

Pair color with a label, icon, or shape so meaning survives for color-blind and low-vision users, and ensure text meets WCAG AA contrast (4.5:1 body, 3:1 large text).

```html
<!-- Bad — color is the only signal -->
<span class="badge badge--locked"></span>

<!-- Good — color plus a text label -->
<span class="badge badge--locked">Locked</span>
```

### `aria-label` only works on interactive/landmark/`role` elements

On a bare `<span>` or `<div>`, `aria-label` is silently ignored, so the label never reaches a screen reader. Either expose a visually-hidden label, or promote the element to an image role.

```html
<!-- Option 1: visually-hidden text, decorative icon hidden from AT -->
<span class="badge">
  <span class="visually-hidden">Locked</span>
  <span class="badge__icon" aria-hidden="true">🔒</span>
</span>

<!-- Option 2: give the element an image role so aria-label is honored -->
<span class="badge__icon" role="img" aria-label="Locked">🔒</span>
```

---

## Numeric columns

Numbers that line up in a column (scores, points, totals) should use fixed-width figures and right alignment:

```css
.num { text-align: right; font-variant-numeric: tabular-nums; }
```

Follow this pattern rather than introducing a monospace font family just for numeric alignment.
