# Routing rulebook with effort levels (Oct 2026)

The owner's reference for which model and effort run each kind of lane. It is the starting point, not a fixed law: the coordinator adjusts routing from lane results (SKILL.md section 4). `owner.md` maps these models to start commands and holds the adjustments.

Effort is the main cost/quality dial. Higher effort buys more thinking tokens, longer latency, and better results on hard or ambiguous work, with strong diminishing returns. Prefer lower effort plus stronger verification (tests, acceptance criteria, owner check) over maxing effort.

## Defaults and general rules

- **Claude Opus 5.5:** default **medium** (Claude Code and apps). Medium already matches or beats the previous Opus high on many coding and knowledge tasks.
- **Claude Sonnet 5.5:** default **medium** in Claude Code, **high** on the pure API. Its levels are recalibrated: do not carry over old settings.
- **GPT-6 Astra / GPT-6.1 Sol:** default usually **medium**. Levels: low, medium, high, xhigh, max (Astra has no "none").
- **DeepSeek V4.1 Flash-1017:** continuous 1-100 (API aliases: low ≈ 50, high ≈ 75, max = 100). Default often high. Settings of 25-50 cut tokens with little quality loss on many tasks.
- Escalate only when the lower level fails twice or the cost of failure is high. Prefer xhigh over max for long agentic coding: max often overthinks on pure coding.

## Role routing and effort

| Role | Primary model + effort | Value / alternative + effort | Escalate when |
|------|------------------------|------------------------------|---------------|
| **Orchestration** | Opus 5.5 **medium** (default) or **high** | Sonnet 5.5 **medium/high**; Astra **high** for the hardest long-horizon work | The task spans many systems, priorities are unclear, or medium failed. Use xhigh only for multi-hour autonomous runs. |
| **Research** | Sonnet 5.5 **medium** or **high** | Gemini 4 Argon (medium/high); DeepSeek **low-high** (50-75) for volume | Conflicting sources, long documents, or deep synthesis: Opus medium/high or Astra high. |
| **Planning** | Opus 5.5 **medium** or **high** | Astra **medium/high**; Sonnet **high** for scoped plans | High ambiguity, multi-constraint tradeoffs, or architecture decisions: Opus high/xhigh or Astra high/xhigh. |
| **Graphics / taste** | Opus 5.5 **medium** or **high** | Astra **medium/high** | Visual hierarchy, 3D, web design, or judging looks: start at high. Max is rarely needed. |
| **Implementation, complex / multi-system** | Opus 5.5 **medium**, then **high** | Sonnet 5.5 **high** | Multi-file, concurrency, migrations, or merge-critical: high or xhigh. Max only after high fails. |
| **Implementation, standard / basic** | Sonnet 5.5 **medium** | DeepSeek **low-medium** (25-50); Sonnet **low** for pure mechanical work | Clear acceptance criteria and tests exist. Go to high only if medium misses edge cases. |
| **Testing and reviewing** | Opus 5.5 **medium** or **high** | Sonnet 5.5 **medium/high**; DeepSeek **high** for a cheap high-recall pass | Security-sensitive, high-stakes, or maximum precision: Opus high/xhigh. Astra high for high-precision review passes. |

## Effort cheat-sheet

| Effort | Best for | Avoid for |
|--------|----------|-----------|
| **Low** | Mechanical edits, extraction, classification, simple renames, high-volume verified work | Anything ambiguous or multi-step |
| **Medium** | Most daily work: well-scoped features, research synthesis, standard implementation, orchestration of clear tasks | Long open-ended agent runs, hard debugging |
| **High** | Multi-file bugs, complex planning, deeper reviews, graphics and taste, harder agent tasks | Pure mechanical or high-volume work |
| **Xhigh** | Long-horizon agentic coding (>30 min), security-sensitive review, ambiguous multi-constraint planning | Everyday tasks (diminishing returns, higher cost) |
| **Max** | Last resort after xhigh failed; the deepest open-ended reasoning | Defaults and routine coding (overthinks, much higher cost) |

## Dispatch heuristics

1. Classify the lane's complexity and its cost of failure first.
2. Start at the recommended model at medium, or low for purely mechanical work.
3. When a lane reports incomplete results, repeats tool failures, or fails verification: raise effort one level, or switch model.
4. Cap max. Xhigh and max need a stated reason or an earlier failure.
5. For many mid-tier lanes, prefer Sonnet or DeepSeek at higher effort over Opus at low.
6. Track cost per successful lane, and adjust routing from the project's real success rates.
