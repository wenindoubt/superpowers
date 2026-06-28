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
- 🟢 work finished. 🟡 non-routine follow-up remains (name it). 🔴 blocked on user input.
- Emit 🟢 ONLY when superpowers:verification-before-completion is satisfied (fresh evidence). Never rubber-stamp green.

## Why the footer matters here (fork-local)

The Stop hook (hooks/stop) reads the LAST line of your final message:
- 🔴 / 🟡 -> handoff suppressed (blocked / ongoing — keep working, recheck later).
- 🟢 -> clean seam; if ready beads remain (per-bead default: no ctx gate), a fresh cmux session is
  spawned on the next `bd ready` bead and THIS session runs `/exit` — an unbounded loop through ready
  work, one bead per fresh context. (Restore a ctx gate with `HANDOFF_CTX_PCT=0.30`; full off-switch
  is `HANDOFF_DISABLE=1`.)

An inaccurate footer mis-drives that automation. Choose the color from the user's perspective: finished, pending-a-specific-step, or blocked.

## Examples

🟢 Updated quick-recap docs with output examples
🟡 Code updated, set PROVIDER_WEBHOOK_SECRET before testing webhooks
🔴 Need the production API key to continue
