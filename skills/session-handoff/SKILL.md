---
name: session-handoff
description: Write a handoff document to docs/superpowers/handoffs/ that captures the state of long-running work so a fresh session can pick it up cleanly, instead of pressing on in an exhausted context. Use when a long multi-step task finishes and more work remains, when reaching a natural phase boundary (a feature is done before the next big chunk), or when the user says "hand off", "write a handoff", "create a handoff doc", "wrap up for a new session", or anything signaling they want to continue in a fresh session. Prefer this over silently continuing once a big task completes.
model: opus
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Session Handoff

<!-- beads-native: fork-local -->
You've been deep in a long task. Continuing in the same context means working with a tired, cluttered window — important details get buried, and the work degrades. The fix is to stop at a clean boundary and let a fresh context take over.

In the beads-native workflow, **state already lives in beads** (see `skills/_shared/beads-workflow.md`): what's done is closed beads, what's left is `bd ready`, decisions are in the decision/epic bead. So a handoff is usually **not a document you write** — it's state the next session reads. You only capture the one thing beads can't: context that lives only in your head when you stop mid-task.

## When to write a handoff

- A long multi-step task just finished and there's a clear "next chunk" remaining.
- You hit a natural phase boundary (a feature/migration/refactor is done; the next phase is distinct work).
- The user explicitly asks for a handoff.

Don't write one for trivial tasks, or when the remaining work is a quick follow-up you can just finish now. A handoff exists to cross a *session* boundary, not to dodge five more minutes of work.

## The workflow (beads-native)

State lives in beads — do NOT write a handoff markdown file.

### 1. Gather real state — don't guess

Ground every claim in evidence. Run `git status`, run the relevant tests, and read the bead state:

```bash
bd list --parent <epic> --status closed --json   # Done
bd ready  --parent <epic> --json                  # Remaining (unblocked); also check open/blocked
bd list --status in_progress --json               # Active right now
```

If you're unsure whether something works, say so on the bead rather than asserting it's done.

### 2. Decide if anything would be lost

- **Clean boundary** (no half-done bead holding context that isn't written down) → write NOTHING. Tell the human:

  *"Clean boundary. New session: say 'do the next ready work'."*

- **Stopped mid-task** with context not captured in any bead → pin ONE append-note to the in-progress bead:

  ```bash
  bd note <in-progress-id> "STOPPED MID-TASK: <what failed / why / what to try next / what NOT to retry>"
  ```

  Append-only notes are a trail — they never overwrite a prior note.

### 3. Output the trigger phrase, not a file path

End with the single line the human acts on in a new session:

```
New session: say "do the next ready work".
```

(Include the note ID if you wrote one.) Don't dump state back into chat — beads is the source of truth.

## Why this works

- **The next task bead is self-contained** (steps + acceptance), so a fresh session just runs the ready loop — usually no handoff writing at all.
- **What's done / what remains** is bead status, not prose that goes stale the moment you save it.
- **Mid-task context** that lives only in your head is the one thing beads can't auto-capture — so that, and only that, earns a note.

## Anti-patterns

- **Writing a handoff markdown file.** State goes in beads; `bd note` on the in-progress bead, nothing more.
- **Asserting work is done without checking.** Run the commands / read bead status. A handoff that lies is worse than none.
- **A vague note** ("continue the work"). Name the next concrete action and the trap to avoid.
- **Dumping the whole state into chat.** The human wants the trigger phrase, not a wall of text.
