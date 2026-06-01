<!-- deep-research-escalation: fork-local -->

# Deep-Research Escalation

Shared logic for the web-research pass in `brainstorming` (step 4) and
`writing-plans`. The `kiln-web-search-researcher` pass runs first and always —
this describes when to AUTO-ESCALATE that unknown to the `/deep-research`
harness (parallel fan-out + adversarial claim verification + cited report).

## When to escalate

After the kiln researcher returns, escalate an unknown to `/deep-research` only
if BOTH gates pass.

**Gate 1 — high-stakes.** The unknown is at least one of:

- **Architecture-deciding** — locks in a hard-to-reverse direction (auth
  library, database, framework, protocol, data model).
- **Contested** — sources are likely to conflict, or recency is decisive
  ("is X still the recommended approach in 2026?").
- **Costly-if-wrong** — security, payments, compliance, auth, or data-loss
  surface.

If none apply, do NOT escalate. Single clear unknowns (a version number, one
documented gotcha) never escalate — kiln already handled them.

**Gate 2 — available.** `/deep-research` is a Claude Code built-in and does not
exist on every harness (Gemini, Copilot, Codex, opencode). Escalate only if
`/deep-research` is available in the current harness. If it is not, stay
kiln-only and say nothing about escalation.

## How to escalate

No user approval. Announce, then invoke:

> Escalating to /deep-research — <one-line why this unknown is high-stakes>.

    Skill(deep-research, args: "<scoped unknown, weaving in the clarifying answers>")

Fold the cited report into the approaches (brainstorming) or task code blocks
(writing-plans). In the `## Research Findings` section, tag which findings came
from `/deep-research` (verified, cited) versus `kiln-web-search-researcher`.
