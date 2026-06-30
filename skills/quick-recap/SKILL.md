---
name: quick-recap
description: Use when adding or following the red/yellow/green final status block convention for agent responses. In this fork the footer also drives hands-free cmux-handoff via the Stop hook.
---

# Quick Recap

<!-- quick-recap: fork-local -->
Make completion state obvious at the end of every response — and give the Stop hook a reliable seam signal for hands-free handoff.

## Status Block

Every response that completes a unit of work must end with a single final line:

🟢 Actual concise status sentence

Rules:
- Under 100 characters, at the very END of the response, nothing after it (no ---, no spacer line).
- 🟢 this unit verified-done. Use 🟢 ALSO for a **soft stall**: you have a non-blocking question or are unsure what's next, but `bd ready` has obvious work and your question changes neither *which* task is next nor *how* to do it — note the question on the bead and let the loop carry it to `bd ready[0]`.
- 🟡 a non-routine follow-up remains that THIS session should finish (name it) — keeps the session working.
- 🔴 **hard blocker only**: a decision only your human can make, where guessing risks slop. Flag it with `bd human <id>` so it's durable, then stop. Do NOT reach for 🔴 just because you have a question — see the soft-stall rule above.
- Emit 🟢 ONLY when superpowers:verification-before-completion is satisfied for the unit you just finished (fresh evidence). Never rubber-stamp green.

## Why the footer matters here (fork-local)

The Stop hook (hooks/stop) reads the LAST line of your final message:
- 🔴 -> hard blocker (human-only decision) -> handoff suppressed; `bd human`-flag it and stop.
- 🟡 -> THIS session keeps working (mid-task follow-up) -> suppressed, recheck at next stop.
- 🟢 -> clean seam; once context ≥ `HANDOFF_CTX_PCT` (default `0.30` in `hooks/stop`) and ready beads
  remain, a fresh cmux session is spawned on the next `bd ready` bead — refreshing the codebase index
  first — and THIS session runs `/exit`. A loop through ready work that self-terminates when `bd ready`
  empties or a 🔴 hard blocker lands. Because a soft stall is 🟢, a non-blocking "what next?" advances
  the loop instead of waiting on the human. (`HANDOFF_CTX_PCT=0` = per-bead, every seam;
  `HANDOFF_DISABLE=1` = off.)

An inaccurate footer mis-drives that automation. Choose the color from the user's perspective: finished, pending-a-specific-step, or blocked.

## Examples

🟢 Updated quick-recap docs with output examples
🟡 Code updated, set PROVIDER_WEBHOOK_SECRET before testing webhooks
🔴 Need the production API key to continue
