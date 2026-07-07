<!-- autonomous-loop: fork-local -->
# Autonomous loop mode

A standing mode for grinding through an already-planned body of work — a beads
epic, a migration, a checklist — **session after session, handing off between
them, until genuinely blocked.** It relaxes two human-in-the-loop gates that
otherwise force a stop on every task, and replaces "ask the user" with
"research first, ask last."

**This mode is OFF by default.** Normal interactive sessions keep every gate.
The carve-outs below apply ONLY when the mode is explicitly entered.

## Entering the mode

You are in autonomous loop mode when ANY of these is true:

- The session's seed prompt contains the marker
  **`AUTONOMOUS-LOOP`** (cmux-handoff injects it; see that skill).
- The user says to keep going until blocked / "don't stop to ask" / runs `/loop`
  over a work queue.

If none hold, you are NOT in this mode — obey the normal gates.

## What changes in the mode

### Carve-out A — pre-specced work skips the design-approval gate

`brainstorming`'s HARD-GATE (present a design, get user approval before any
implementation) exists so unexamined assumptions don't waste work. When the task
is **already specced** — an existing `decision` bead (the design) plus a scoped
task bead (steps + acceptance in its body) — that approval already happened. Do
NOT re-present the design for approval. Read the decision + task beads, then
implement per the task body. Record any non-obvious call you make with `bd note`
on the task bead instead of asking.

### Carve-out B — decide, don't ask

`using-superpowers`' "clarifying questions before action" and brainstorming's
"one question at a time" become: **make the defensible default decision, state
it, note it on the bead, and continue.** Do not open an `AskUserQuestion` for
anything that has a sane default or a researchable answer.

Both carve-outs are subordinate to the research-first rule below: you may only
"decide and continue" AFTER research, and you may only stop-and-ask when research
genuinely can't settle it.

## Research-first before "blocked" (MANDATORY)

You are **not allowed to consider yourself blocked** — and definitely not allowed
to ask the user — until you have exhausted research. In order:

1. **Codebase research.** Read the relevant code/tests/config (codebase-memory-mcp
   if available: `search_graph` / `trace_path` / `get_code_snippet`, else
   Grep/Glob/Read). Most "which pattern here?" questions are answered by how the
   surrounding code already does it — follow the existing convention.
2. **Web research — REQUIRED for any architectural / design / best-practice
   question.** Before treating an approach question as blocking, search the web for
   the current, standardized, best-practice answer. Dispatch
   `kiln-web-search-researcher` (or `WebSearch`/`WebFetch`) and, for high-stakes /
   contested / costly-if-wrong unknowns, escalate to `/deep-research` if available.
   Prefer the latest stable, widely-adopted, standardized approach; cite the source
   in a `bd note` so the choice is auditable. "I'm not sure what the best way is"
   is NEVER a reason to stop — it's a reason to search.

Only once BOTH are exhausted and the question remains may you treat it as a
candidate block. Then apply the stop test below.

## When you are actually blocked (the stop test)

After research, you are **fully blocked** only in one of these cases:

1. **Dependency-blocked** — no ready bead, but open beads remain (they're waiting
   on other work). → Surface the blocker; if handing off, seed
   `unblock <id>: <blocker>` rather than new feature work.
2. **Queue empty** — no ready beads AND no open beads. The epic/queue is done. →
   Stop; tell the human it's complete.
3. **User-only decision** — a genuine product/preference/irreversible-or-external
   call that research cannot answer (secrets, spending money, a destructive or
   outward-facing action, or a real product judgment with no default). → Do NOT
   guess. Surface the specific question. If handing off, hand off **idle** (no
   auto-prompt) with the question stated so the human answers before work resumes.

Anything short of these three is not a block — keep going.

## Self-perpetuation

The loop only continues if each session re-arms it. On finishing a task
(committed + pushed + bead closed per the project's session workflow), immediately
invoke `cmux-handoff` for the NEXT ready bead. cmux-handoff re-injects the
`AUTONOMOUS-LOOP` marker into the new seed prompt, so the fresh session stays in
mode — until one of the three stop conditions ends it.
