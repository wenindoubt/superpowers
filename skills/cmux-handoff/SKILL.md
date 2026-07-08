---
name: cmux-handoff
description: Hand off long-running work to a FRESH Claude Code session spawned in a new cmux tab (via the `clxp` alias), seeded with a prompt that points the new session at the remaining beads work. Captures any un-encoded mid-task context as a `bd note` first. Use when a long multi-step task finishes and a clear next chunk remains, at a natural phase boundary (a feature/migration/refactor is done before the next big chunk), or when the user says "hand off", "write a handoff", "wrap up for a new session", "/cmux-handoff", or anything signaling they want to continue in a fresh session. Prefer this over silently continuing once a big task completes.
argument-hint: [handoff prompt]
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# cmux-handoff

<!-- beads-native + cmux: fork-local -->
You've been deep in a long task. Continuing in the same context means working with a tired, cluttered window — details get buried and the work degrades. The fix: stop at a clean boundary and let a **fresh session** take over — literally, in a new cmux tab with its own context window.

This skill does two jobs:

1. **The brain** — make sure nothing in your head is lost. State already lives in beads (`skills/_shared/beads-workflow.md`): done = closed beads, remaining = `bd ready`, decisions = the decision/epic bead. The only thing beads can't auto-capture is un-encoded mid-task context — that earns ONE `bd note`. You do **not** write a handoff markdown file.
2. **The hands** — spawn the fresh session via `scripts/handoff.sh`, seeded with a one-line prompt that aims it straight at the remaining `bd ready` work.

## When to hand off

- A long multi-step task just finished and there's a clear "next chunk" remaining.
- A natural phase boundary (a feature/migration/refactor is done; the next phase is distinct work).
- The user asks, or runs `/cmux-handoff`.
- **Hook-triggered (hands-free path):** when the Stop hook invokes this skill (context full + clean 🟢 seam), run the whole workflow autonomously — do NOT ask the user to confirm the handoff. Asking defeats the automatic path.

Don't fire for trivial tasks, or when the remaining work is a quick follow-up you can just finish now. A handoff crosses a *session* boundary — it is not a way to dodge five more minutes of work.

## Workflow

### 1. Close out the finished work — get real closure

Ground every claim in evidence, then make the bead state reflect reality. Run `git status`, run the relevant tests, read the bead state:

```bash
git status
# run the relevant tests
bd list --status in_progress --json               # what's claimed right now
bd list --parent <epic> --status closed --json    # already done
```

- **The finished task is actually done** (tests pass, committed) but its bead is still claimed/open → **close it** so the next session inherits true state:

  ```bash
  bd close <id> --reason "<what shipped> (verified: <test/command>)"
  ```

  The executor normally closes its own bead; if it didn't, closing here is the closure. **Never close work that isn't actually done.**

- **Stopped mid-task** (NOT done) → do not close. Pin ONE append-note to the in-progress bead so the context in your head survives:

  ```bash
  bd note <in-progress-id> "STOPPED MID-TASK: <what failed / why / what to try next / what NOT to retry>"
  ```

  Append-only notes are a trail — they never overwrite a prior note.

If you're unsure whether something works, say so on the bead rather than asserting it's done.

### 1b. Fold durable learnings into the project's conventions doc

If the project keeps a durable, checked-in conventions doc (`CLAUDE.md`, `AGENTS.md`, or similar), fold this session's **durable, non-obvious** learnings into it before handing off — recurring gotchas, patterns, decisions, build/release facts the next session would otherwise re-discover. Skip if the project keeps no such doc.

- **Update** an existing entry rather than duplicating; match the doc's own style/section.
- Capture only what is NOT already obvious from the code, git history, or an existing entry. One-off/ephemeral context is a `bd note` on the bead, not a durable convention.
- **Never edit inside a generated/managed block** (e.g. `<!-- BEGIN … -->` fences) — it gets overwritten on regen.
- Commit it with the session's work so the step-4 push carries it.

### 2. Pick the next work + compose the seed prompt

- If the user passed a prompt to `/cmux-handoff` → use it **verbatim** (skip to step 3). Don't paraphrase — the point of a handoff is the new session receives exactly what was intended.
- Otherwise **let beads tell you what's next** — don't guess:

  ```bash
  bd ready --parent <epic> --json   # unblocked, ready-to-start beads, in order
  ```

  - **A bead is ready** → name *that concrete bead* in a one-line seed prompt (it's self-contained: steps + acceptance live in its body):

    ```
    AUTONOMOUS-LOOP (continue until fully blocked; see skills/_shared/autonomous-loop.md). Continue epic <epic-id>. If codebase-memory-mcp is available, first refresh the index (`detect_changes`; re-run `index_repository` if stale), then use it to explore. Next ready task: <next-id> "<title>" — claim it (`bd update <next-id> --claim`), then do it per its bead body. When done (committed + pushed + bead closed), invoke cmux-handoff for the next ready bead to keep the loop going. <If a note was pinned: stop-context is in the note on <in-progress-id>.>
    ```

    <!-- autonomous-loop: fork-local -->
    **The `AUTONOMOUS-LOOP` marker is what perpetuates the loop.** It puts the new session in autonomous loop mode (`skills/_shared/autonomous-loop.md`): pre-specced beads skip the brainstorming approval gate, it decides-not-asks (research-first before any block), and — crucially — its closing clause tells it to invoke cmux-handoff again when its task is done. So each hop re-arms the next until a stop condition fires (below). Include the marker + closing clause for epic/queue grinding (the default). OMIT both for a genuine one-off handoff the user asked for as a single hop, and NEVER inject them into a **verbatim** user prompt.

    <!-- codebase-memory-mcp: fork-local -->
    **Refresh-then-traverse.** A handoff means code changed, so the new session's index is stale — the SessionStart "Code Discovery Protocol" hook only indexes when a repo is *unindexed*, never refreshes a stale one. So the seed prompt above tells the fresh session to `detect_changes` and re-`index_repository` (only if stale) before traversing via `search_graph`/`trace_path`/`get_code_snippet`. Gate on availability — drop the clause if codebase-memory-mcp isn't in play. **Verbatim user prompts (above) stay verbatim — don't inject the refresh; the new session's normal indexing covers it.**

  - **Nothing ready but open beads remain** → they're blocked. Seed `unblock <id>: <blocker>`, not new feature work.
  - **Nothing ready, no open beads** → the epic is **done**. Don't spawn a session for nothing — **notify the human** and **stop here** (no reaping — the loop ends, remaining tabs stay for review):

    ```bash
    cmux notify --title "epic <epic-id> complete" --body "no ready beads left — loop finished" --surface "$CMUX_SURFACE_ID"
    ```
  <!-- autonomous-loop: fork-local -->
  - **A ready task needs a user-only decision** (research already exhausted per `skills/_shared/autonomous-loop.md` — a secret, spend, destructive/outward-facing action, or a real product call with no default) → do NOT guess and do NOT auto-spawn. Hand off **idle** (step 3, no prompt) with the specific question stated for the human, or surface it and stop. This is the third genuine stop condition; anything a codebase or web search could answer is NOT one — research first.

  Keep the prompt to **one line**. No newlines (cmux may submit early). No leading `/` (it opens Claude's slash-command menu instead of sending text). Drop the stop-context clause if no note was pinned.

### 3. Spawn the fresh session — only inside cmux

```bash
if [ -n "${CMUX_SURFACE_ID:-}" ]; then
  sh skills/cmux-handoff/scripts/handoff.sh "<seed prompt>"
fi
```

Run the script (skill-relative path) with the seed prompt as a **single quoted argument**. With no prompt, run it with no arguments — the new session launches and is left idle.

**Graceful fallback — not in cmux (`CMUX_SURFACE_ID` unset):** you've still done the brain (closure done, next work resolved, any note pinned). Skip the spawn and hand the human the *concrete* next step to paste into a fresh session:

```
New session, next: <next-id> "<title>" — if codebase-memory-mcp is available refresh the index first (detect_changes, re-index if stale), bd update <next-id> --claim, then do it.  Context: note on <in-progress-id>.
```

### 4. Relay the result

The script prints a one-line summary and uses exit codes:

- **0** — success: `prompt submitted` (handed off) or `left idle` (no prompt). Tell the user the new tab's name (the next bead id); the view auto-switched to it. The handoff session takes over. On a prompted handoff the pool was also bounded (see *Bounding the session pool*) — mention it only if a tab was actually reaped or a reap-error notification fired.
- **1** — setup problem (not in cmux, `cmux` missing, or tab creation failed). Relay what the error said.
- **2** — the tab + `clxp` launched, but the agent prompt wasn't ready in time, so the prompt was **not** submitted. Tell the user to switch to the named tab and paste the prompt (the script echoed it).

## Bounding the session pool (the reaper)

A long autonomous loop hands off session→session→session; without a bound, cmux tabs pile up (each is a live Claude Code + node process). `handoff.sh` bounds the pool automatically — **no action needed in this skill's workflow**, but know how it behaves:

- On a **successful prompted handoff only**, the calling session retires itself into a FIFO ring (`~/.claude/state/cmux-handoff-ring.tsv`, keyed on stable surface **UUIDs**) and closes the oldest already-retired tabs so only **`CMUX_HANDOFF_KEEP` (default 5)** stay alive: the fresh worker + the `KEEP-1` most-recent finished predecessors.
- **The safety invariant:** reaching `handoff.sh` *means* this session already committed + pushed + closed its bead (step 1). So "in the ring" ≡ "reap-safe" — nothing unsaved. A session still mid-task, or idled awaiting a human decision (the stop conditions in step 2), **never runs `handoff.sh`, so is never in the ring and never reaped.** The reaper needs no runtime idle-detection; ring membership is the gate.
- It **never** closes the surface running the script (self), the just-spawned child, or the currently-focused tab (a human may be viewing it). A crashed session that vanished from `cmux tree` is pruned from the ring for free.
- **Idle handoffs don't reap** (no prompt = a manual "open a fresh session", caller isn't necessarily done). Only the prompted autonomous-loop path bounds the pool.
- On a reap failure it fires a `cmux notify` ("reap error") and keeps that entry for next time.

Tune with env: `CMUX_HANDOFF_KEEP` (pool size; `<2` is clamped to 2) and `CMUX_HANDOFF_RING` (registry path). The spawned tab is **named after the next bead id** (parsed from the seed prompt's `task: <id>`) so a pool of tabs is scannable at a glance; a random `<adj>-<noun>-NN` handle is the fallback when no bead id is present.

## Why this works

- The next task bead is self-contained (steps + acceptance), so the fresh session just runs the ready loop — usually no handoff prose at all.
- Done / remaining is bead status, not text that goes stale the moment you save it.
- Mid-task context that lives only in your head is the one thing beads can't auto-capture — so that, and only that, earns a note.
- The new session boots with a clean context window aimed at exactly the right work.

## Prerequisites

- Runs from **inside a cmux terminal** running Claude Code (`CMUX_SURFACE_ID` is set automatically there). Unset → the graceful fallback in step 3 applies.
- The user's interactive shell defines the `clxp` alias (`claude --dangerously-skip-permissions --strict-mcp-config --mcp-config ~/.claude/mcp-personal.json`). The new tab is a real interactive shell, so the alias resolves there. The handoff launches it as `clxp --chrome` (`LAUNCH_CMD` in `scripts/handoff.sh`) so claude-in-chrome is available in the fresh session.

## Notes & limits

- **Single-line prompts** are most reliable. A prompt with newlines may submit early; one starting with `/` opens the slash menu. For those, hand off idle (no prompt) and let the user paste.
- The readiness check polls for Claude Code's input caret (`❯`), set as `READY_MARKER` at the top of `scripts/handoff.sh` — adjust there if a future Claude Code UI changes the caret.
- The tab is named after the next bead id when the seed prompt carries one (`task: <id>`); otherwise a random `<adj>-<noun>-NN` handle (cmux allows duplicate names — the 2-digit suffix makes collisions unlikely and harmless).
- The pool bound (`CMUX_HANDOFF_KEEP`, default 5) is enforced only on prompted handoffs and only over sessions spawned through this script (tracked in the ring). Tabs you opened by hand are never touched.

## Anti-patterns

- **Writing a handoff markdown file.** State goes in beads; `bd note` on the in-progress bead, nothing more.
- **Asserting work is done without checking.** Run the commands / read bead status. A handoff that lies is worse than none.
- **A vague note or seed prompt** ("continue the work"). Name the next concrete action and the trap to avoid.
- **Paraphrasing a user-given prompt.** Pass it verbatim.
- **Auto-spawning for trivial work.** Cross a session boundary, not a five-minute follow-up.
