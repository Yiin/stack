---
name: working-on-design
description: "Router for UI/UX work: classifies the task, loads only the matching layers. Use for any change to how a feature looks, moves, or is interacted with."
---

# Working on Design

Router with progressive disclosure. Do NOT load every layer — classify the task, load only the matching layers, then do the work. Most tasks need one or two layers plus the universal floor.

## Step 1 — Classify the task

Identify which facets the task touches:

| Facet | Signals |
| --- | --- |
| Control-level UX | Forms, inputs, validation, toasts, dialogs, micro-interactions — making an element or flow feel great, not restyling it |
| Aesthetic direction | New UI, redesign, "make it look good/modern", landing page, visual identity |
| Concrete tokens | Need a palette, font pairing, style system, product-type conventions, stack-specific rules |
| Motion — build | Adding/implementing animations, transitions, enter/exit, hover/press states |
| Motion — review | Reviewing a diff that contains animation code |
| Motion — audit/find | "Improve the animations", "what should animate here?" |
| Interaction physics | Drag, swipe, sheets, springs, momentum, rubber-banding, gesture-driven UI |
| Materials & depth | Translucency, blur layers, shadows, elevation, glass chrome |
| Charts | Any chart, graph, dashboard viz, stat tile, KPI row |
| Deliverable is an artifact | Output is an HTML page for the user, not app code |

## Step 2 — Universal floor (always applies, no loading needed)

- **States**: every interactive element needs hover, active, focus-visible, disabled; every view needs loading, empty, and error states.
- **Accessibility**: WCAG AA contrast, 24px+ touch targets, keyboard reachable, `prefers-reduced-motion` respected (gentler, not zero), hover effects gated behind `@media (hover: hover) and (pointer: fine)`.
- **Responsive**: no horizontal page scroll; wide content scrolls in its own container.
- **Consistency beats novelty**: in an existing project, use its design system — theme tokens (shadcn CSS variables), existing components, its spacing scale. Never hardcode one-off colors or invent a parallel visual style for one feature; extend what's there. Designing from scratch with no direction is the only case where "avoid the LLM default looks" applies (cream + serif + terracotta; near-black + one acid accent; editorial hairlines) — and that's a signal to load frontend-design, not a checklist item.

## Step 3 — Load matching layers

The motion and apple-design layers below are archived skills. They live in `~/.agents/skills-archive/` and load on demand by reading the file named, not through the Skill tool.

### Control-level UX → ux lookup + motion values (the most common case)
The default reason this skill gets loaded: giving each element the interaction quality that used to be too expensive to hand-build. Combine:
1. `python3 ~/.claude/skills/ui-ux-pro-max/scripts/search.py "<the control or pattern>" --domain ux` — per-control do/don'ts with severity (validation timing, toast lifetimes, focus handling, touch targets).
2. `~/.agents/skills-archive/review-animations/STANDARDS.md` — the feedback-motion values (press scale, durations, easing, interruptibility).
3. `~/.agents/skills-archive/apple-design/SKILL.md` when the control is gesture-driven or layered (sheets, drawers, drag).
Visual style stays whatever the project's design system says; this layer is about behavior.

### Aesthetic direction → `frontend-design` skill
Invoke `Skill(frontend-design:frontend-design)`. Persona-driven direction for typography, color, layout, copywriting, and avoiding templated defaults. Load when designing something new or reshaping the look of something that exists.

### Concrete tokens → ui-ux-pro-max CLI (do NOT invoke the skill)
The `/ui-ux-pro-max` SKILL.md costs ~12k tokens and its prose is stale; its CSV data is good. Query the data directly:

```bash
cd ~/.claude/skills/ui-ux-pro-max
# Full design system for a product type (palette, style, typography, landing pattern):
python3 scripts/search.py "<product type + keywords>" --design-system -f markdown
# Targeted lookup — domains: style,color,chart,landing,product,ux,typography,icons,react,web,google-fonts
python3 scripts/search.py "<query>" --domain <domain>
# Stack-specific do/don'ts — react,nextjs,vue,svelte,astro,swiftui,react-native,flutter,nuxtjs,nuxt-ui,html-tailwind,shadcn,jetpack-compose,threejs,angular,laravel
python3 scripts/search.py "<query>" --stack <stack>
```

Returns top-3 matches, token-cheap. Palettes are WCAG-checked. Treat results as a starting point that `frontend-design` taste and the project's own system override.

### Motion — build → read `~/.agents/skills-archive/review-animations/STANDARDS.md`
The exact values: easing decision order and custom cubic-beziers, per-element duration budgets (UI < 300ms), spring configs, `@starting-style`, interruptibility, GPU-only properties, stagger, gesture velocity math. Use these values when writing any animation code; never approximate.

### Motion — review a diff → read `~/.agents/skills-archive/review-animations/SKILL.md` + `STANDARDS.md`
Apply its ten standards and output format (findings table + Block/Approve verdict).

### Motion — audit or find opportunities → read the archived skill
- Codebase-wide audit with handoff plans: read `~/.agents/skills-archive/improve-animations/SKILL.md`
- "What could/should animate?": read `~/.agents/skills-archive/find-animation-opportunities/SKILL.md`

### Interaction physics, materials & depth, typography feel → read `~/.agents/skills-archive/apple-design/SKILL.md`
Apple's fluid-interface principles for the web: interruptible springs (damping/response), velocity handoff, momentum projection, rubber-banding, 1:1 drag tracking, translucent materials and shadow depth, optical typography (tracking/leading by size), reduced-transparency/contrast signals. Load for anything gesture-driven or involving layered/translucent surfaces.

### Charts → `dataviz` skill
Invoke `Skill(dataviz)` before writing any chart code, in any medium. Non-negotiable there: chart colors are validator-gated, not hand-picked, and chart/dashboard numerics use system sans even when the surrounding page has a display face.

### Artifact deliverables
- Reviewable HTML for the user locally → `Skill(lavish)`
- Published claude.ai artifact → `Skill(artifact-design)`

## Precedence when layers conflict

1. Explicit user direction.
2. The project's existing design system and tokens.
3. `dataviz` rules inside any chart (its scope is narrow; it wins there).
4. `frontend-design` taste for everything else visual.
5. ui-ux-pro-max lookup results — data, not law.

## Typical flows

- `/cook-it <new feature UI>` → floor + frontend-design + (tokens lookup if starting from nothing) + STANDARDS.md when adding motion.
- `/cook-it <dashboard page>` → floor + dataviz + tokens lookup (`--design-system`).
- `/cook-it <drawer/sheet/swipe interaction>` → floor + apple-design + STANDARDS.md.
- Reviewing UI changes → floor + review-animations bar for any motion in the diff.
