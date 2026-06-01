# Deep-Research Escalation (fork-local)

**Date:** 2026-06-01
**Status:** Design approved
**Scope:** Fork-local only. NOT for upstream.

## Problem

The fork-local web-research pass in `brainstorming` and `writing-plans` always
dispatches `kiln-web-search-researcher` — a single lightweight subagent with no
adversarial claim verification and no parallel fan-out. For most unknowns
(current version, one gotcha) that is the right tool: fast, cheap, in-loop.

For a minority of unknowns — architecture-deciding, contested, or costly-if-wrong
— a single unverified web pass is too weak. Claude Code ships a built-in
`/deep-research` harness (parallel fan-out searches → adversarial claim
verification → cited synthesized report) that is the right tool for those cases.

We want to use it, but only when it earns its higher cost/latency — never as a
mandatory step on every run.

## Goal

Let the model **self-escalate** a web-research pass from the kiln agent to
`/deep-research` when (and only when) the unknown is high-stakes — automatically,
with no user approval prompt, announced for transparency, and silently degrading
to kiln-only on harnesses where `/deep-research` does not exist.

## Non-Goals

- Not replacing `kiln-web-search-researcher`. kiln runs first and always; deep-research augments.
- Not upstream. This is a fork-local feature, marked as such.
- No config, no env var, no per-query user prompt.
- Not gating on codebase-research (`kiln-research_codebase_github`) or the unrelated `autoresearch` skill.

## Design

### Architecture

One shared markdown file holds the escalation logic; both research-pass skills
point to it by repo-relative path (the convention already used by
`skills/brainstorming/SKILL.md` to reference `skills/brainstorming/visual-companion.md`).

```
skills/brainstorming/deep-research-escalation.md   <- canonical logic (NEW)
skills/brainstorming/SKILL.md                      <- step 4 pass: add pointer
skills/writing-plans/SKILL.md                      <- research pass: add pointer
```

Brainstorming owns the file (primary research-pass owner). writing-plans
references the same repo-relative path. No new top-level dir, no relative-path
fragility, single source of truth (DRY).

### Control flow

Default behavior is unchanged: the kiln agent runs the pass. The shared logic
adds a conditional, fully model-judged auto-escalation:

```
run kiln-web-search-researcher (default, always)
    │
    ▼
high-stakes? (architecture-deciding / contested / costly-if-wrong)
    │ no ──────────────► proceed with kiln result (today's behavior)
    │ yes
    ▼
/deep-research available in this harness?     ← soft check, no detection code
    │ no ──────────────► proceed with kiln result
    │ yes
    ▼
ANNOUNCE + auto-invoke (no approval prompt):
    "Escalating to /deep-research — <why>."
    Skill(deep-research, args = scoped unknown)
    fold cited report into approaches
```

kiln runs first and always. deep-research augments, never replaces. Both gates
(high-stakes AND available) must pass or the flow is identical to today.

### Trigger criteria (what "high-stakes" means)

The shared file defines this concretely so the model is not guessing. Escalate
only if the unknown is at least one of:

- **Architecture-deciding** — the choice locks in a hard-to-reverse direction
  (auth library, database, framework, protocol, data model).
- **Contested** — sources are likely to conflict, or recency is decisive
  ("is X still the recommended approach in 2026?").
- **Costly-if-wrong** — security, payments, compliance, auth, or data-loss surface.

If none apply, no escalation. Single clear unknowns (a version number, one
documented gotcha) never escalate — kiln handles them.

### Announce mechanics

- The escalation is **announced, not offered**: one line stating it is escalating
  and why, then it invokes — matching superpowers' existing
  "Using [skill] to [purpose]" convention. Transparency, not permission.
- Invocation: `Skill(deep-research, args: "<scoped unknown from clarifying answers>")`.
  The cited report then feeds the 2-3 approaches.

### Harness gate

Soft "if available" check — no harness-detection code. `/deep-research` is a
Claude Code built-in and does not exist on Gemini / Copilot / Codex / opencode.
The shared file instructs: offer escalation only if `/deep-research` is available
in the current harness; otherwise stay kiln-only and silent. The feature
self-degrades; non-CC harnesses see today's behavior.

### Fork-local marking

Both SKILL.md edits and the new file carry a `<!-- deep-research-escalation:
fork-local -->` marker, matching existing fork-local markers
(`superpowers-teams`, `codebase-memory-mcp`). Keeps upstream-sync diffs obvious.

### Spec output

When a pass escalates, the design doc's `## Research Findings` section tags which
findings came from `/deep-research` (verified, cited) vs `kiln-web-search-researcher`.

## Affected files

| File | Change |
|---|---|
| `skills/brainstorming/deep-research-escalation.md` | NEW — canonical escalation logic, trigger criteria, harness gate |
| `skills/brainstorming/SKILL.md` | "Mandatory Web-Research Pass" section: add pointer to shared file + fork-local marker |
| `skills/writing-plans/SKILL.md` | web-research pass section: add pointer to shared file + fork-local marker |

## Testing

Skill-behavior change — no automated test harness for the escalation judgment.
Verify by inspection + manual scenarios:

1. **Low-stakes unknown** (e.g. "current stable version of lib X") → no escalation, kiln only. (Regression check: today's behavior preserved.)
2. **High-stakes unknown** (e.g. "auth approach for a payments app, 2026") in CC → announces + invokes deep-research.
3. **High-stakes unknown on non-CC harness** → no escalation, kiln only, no dead invoke.

No eval evidence required since this is fork-local and additive (default path unchanged).

## Research Findings

No external research required for this task. All components are known:
`/deep-research` (CC built-in harness), `kiln-web-search-researcher`
(`~/.claude/agents/kiln-web-search-researcher.md`), and the two fork-local
web-research passes already in the skills.

## Open Questions

None.
