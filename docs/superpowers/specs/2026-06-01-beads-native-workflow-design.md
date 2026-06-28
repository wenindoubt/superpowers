# Beads-Native Workflow Design

**Date:** 2026-06-01
**Status:** Approved — ready for implementation plan
**Topic:** Make superpowers store specs, plans, and handoffs entirely in beads (`bd`) instead of markdown files, across all projects.

## Goal

Replace markdown-file artifacts (specs, plans, handoffs) with **beads as the single source of truth** in every project. Five superpowers skills become beads-native so that "do the next ready work" is all a fresh session needs.

## Background / Motivation

Today three superpowers skills emit markdown under `docs/superpowers/`:
- `brainstorming` → `specs/*.md`
- `writing-plans` → `plans/*.md`
- `session-handoff` → `handoffs/*.md`

And two skills *consume* the plan markdown:
- `subagent-driven-development`, `executing-plans` → walk `- [ ]` checkboxes

Markdown artifacts go stale the moment they're written, can't be queried, clobber each other on parallel edits, and carry no dependency/ready-work model. Beads (Steve Yegge's `bd`, Dolt-backed, v1.0.3 installed) is purpose-built as agent working memory: dependency-aware ready queue, status, time-travel, real merges, SQL queries — with a git-tracked JSONL export.

Yegge's own guidance (AGENTS.md): **"Do NOT create markdown TODO lists. Do NOT duplicate tracking systems."** This design follows that.

## Scope

**Five skills change** (fork-local edits to this repo's `skills/`):
1. `brainstorming` — emits a `decision` bead
2. `writing-plans` — emits an `epic` bead + `task` children
3. `subagent-driven-development` — consumes beads via `bd ready`
4. `executing-plans` — consumes beads via `bd ready`
5. `session-handoff` — shrinks to "pin un-encoded state to a bead, else no-op"

## The Bead Model

Per feature, three layers (chosen structure: separate decision bead — option "B" from brainstorm):

```
📄 decision bead  (type: decision)        ← from brainstorming
   --description : the spec
   --design     : chosen approach + tradeoffs/rationale
   --notes      : Research Findings
   ▲ linked via --spec-id
📁 epic bead  (type: epic)                 ← from writing-plans
   body: feature goal, architecture summary, tech stack
   └── 📋 task beads (type: task, --parent epic)   ← one per behavioral unit
        --description : the 5 TDD steps as a checklist + code blocks
        --acceptance  : "tests pass + committed"
        order/deps    : blocks: chains
        discovered work → new bead, discovered-from: link
```

**Granularity rule (grounded in research):** a bead = a *behavioral unit* you could meaningfully block on, reorder, or assign. TDD micro-steps (write test / run / implement / run / commit) are a fixed serial ritual — they live in the task body, **never as separate beads** (confirmed anti-pattern: inflates DB, noisy dep chains, zero `bd ready` parallelism benefit).

**Naming:** short prefix per repo (BP#7), derived from repo name (e.g. `superpowers` → `sp`).

**Task lifecycle:**
`bd ready` surfaces → `bd update --claim` → agent executes body steps → verify `--acceptance` → `bd close --reason "..."` (only after `git push`).

## Skill Rewrites

Each skill swaps its I/O from markdown files to `bd` commands; core logic (clarifying questions, TDD, two-stage review) is unchanged.

### brainstorming
- Was: write `specs/*.md` + commit
- Now: `bd create --type decision --title "..." --description=-` (spec via stdin), `--design` (tradeoffs), research findings → `--notes`. Hand writing-plans the decision bead ID.

### writing-plans
- Was: write `plans/*.md`
- Now:
  - `bd create --type epic --title "..." --spec-id <decision-id>` (goal/arch/stack in body)
  - per task: `bd create --type task --parent <epic> --description=- --acceptance "tests pass + committed"` (steps + code in body via stdin)
  - order: `bd dep add <taskB> blocks <taskA>` chains
  - web-research pass + self-review unchanged (now scan bead bodies)

### subagent-driven-development / executing-plans
- Was: walk markdown `- [ ]` checkboxes
- Now the loop:
  ```
  bd ready --json --parent <epic>
  bd update <id> --claim
  → fresh subagent: execute steps from bead body
  → verify --acceptance
  bd close <id> --reason "..."   # only after git push
  → two-stage review (preserved)
  → repeat
  ```

### Shared hard rules (baked into all five)
- Never `bd edit` (opens `$EDITOR`, agents can't drive) → always `bd update` w/ flags or `--body-file -` / stdin
- Always `--json` when parsing
- `--claim` before work, `bd close --reason` after
- Commit messages carry `(bd-xxx)`
- **Work is not done until `git push` succeeds**
- Read structured execution metadata before prose

## Handoff Model

Handoff stops being a document. State is *read*, not written.

**Auto-derived (no writing):**
| Old handoff section | Query |
|---------------------|-------|
| What's Done | `bd list --parent <epic> --status closed` |
| What Remains | `bd ready --parent <epic>` + open/blocked |
| In-progress | `bd list --status in_progress` |
| Key files & decisions | already in decision `--design` + task bodies |

**Default — clean boundary: write nothing.** Each task bead is self-contained, so a fresh session just runs the ready loop. The trigger phrase **"do the next ready work"** maps (via per-repo AGENTS.md) to: `bd ready --json` → claim top unblocked task → execute → close. Deterministic because writing-plans sets `blocks` + `--priority`.

**Only when stopping mid-task** with un-encoded context (a trap hit, an abandoned approach): one append-note **on the in-progress bead**:
```
bd note <id> "STOPPED MID-TASK: approach X failed because Y. Try Z. Don't retry X."
```
Append-only = the trail-preservation the old skill hand-rolled, for free.

**session-handoff becomes:** detect whether any context would be lost; if clean, output *"Clean boundary — new session: say 'do the next ready work'."*; else pin one note to the in-progress bead.

## Beads in All Projects

**Per-repo setup — `bd init` once:**
- Prefix from repo name, short
- **Not** `--stealth` (beads is committed = source of truth)
- `bd setup claude` wires AGENTS.md for Claude Code auto-load

**Ask-first init:** when a skill hits a repo with no `.beads/`, it **asks** the user (confirm + prefix) before running `bd init`. Never silent.

**Git tracking model (git-only — no Dolt remote):**
| Path | Git | Why |
|------|-----|-----|
| `.beads/issues.jsonl` | commit | text, diffable, portable source |
| `.beads/config*` | commit | prefix/settings |
| `.beads/dolt/` | gitignore | local engine, rebuilt from JSONL |

Fresh clone → `bd bootstrap` rebuilds Dolt DB from committed JSONL. Git is the sync layer; Dolt is the local working engine.

**The "all projects" lever:** the five skills are global (load in every project). Making them beads-aware = beads everywhere. Each skill's first action: `.beads/` exists? → no: ask → `bd init`; yes: proceed.

**AGENTS.md (generated by `bd init`)** carries per-repo: the "do the next ready work" convention + the hard rules. Claude Code auto-loads it.

## Out of Scope (YAGNI)

- **Dolt remote** (DoltHub / S3 / GCS / `file://`). Git-already-syncs-JSONL is sufficient for a personal multi-project setup. Add later only if multi-machine real-time DB merge or full Dolt-commit granularity is actually needed — `bd dolt remote add origin <url>`, no design change.
- **Migrating existing markdown** specs/plans/handoffs into beads. New work is beads-native; old docs stay as-is.

## Bootstrapping Note (chicken-egg)

The beads-emitting skills don't exist yet and this repo has no `.beads/`. Therefore **this design doc is written as markdown** (current skill behavior). The implementation plan that follows builds the beads workflow; *future* superpowers work dogfoods beads.

## Version Gotcha

Installed: `bd` v1.0.3. v1.0.4 is current stable; **v1.0.5 is gated (sync-corruption bug)** — do not auto-upgrade past 1.0.4 until 1.0.6.

## Research Findings

Retrieved 2026-06-01 via web research on Yegge's beads docs.

- **Granularity:** No over-decomposition warning exists; bias is toward *smaller* issues ("quadratically cheaper" sessions, agents at start of context window). But a **2-minute floor** keeps sub-2-min mechanical steps out of the tracker. TDD micro-steps as beads = unsupported/bad. Source: *Beads Best Practices* #6; *Introducing Beads*.
- **Source of truth:** Beads (Dolt DB) is explicitly authoritative. "Do NOT create markdown TODO lists." JSONL is an export, *not* the source of truth. Source: `AGENTS.md`.
- **Fields:** `--design` for rationale, `--acceptance` for done-definition, `--notes`/`--description` for narrative. Never `bd edit`. Source: `AGENTS.md`.
- **Dependencies:** `blocks` (hard ordering, powers `bd ready`), `parent-child` (hierarchy only — NOT cross-cutting deps), `related` (non-blocking), `discovered-from` (mid-task discovery, the signature agent pattern). Source: FAQ, `AGENTS.md`.
- **Ready/workflow loop:** `bd ready --json` → inspect metadata → `--claim` → do → `bd close --reason` → **not done until `git push`**. Source: `AGENTS.md` "Landing the Plane".
- **Best-practices list (verbatim):** doctor regularly; keep DB small; upgrade + daily hygiene; **plan outside beads then import**; restart agents frequently; file lots of issues (>2min); short prefix; file bug reports; tell others. Source: *Beads Best Practices*.
- **Plan-outside-then-import (#4):** maps to our pipeline — brainstorming = the free-form "outside" planning; writing-plans = the "file epics+issues" import step.
- **Version:** v1.0.4 stable, v1.0.5 gated, v1.0.3 installed (fine).

**Sources (retrieved 2026-06-01):**
- https://steve-yegge.medium.com/beads-best-practices-2db636b9760c
- https://steve-yegge.medium.com/introducing-beads-a-coding-agent-memory-system-637d7d92514a
- https://github.com/steveyegge/beads/blob/main/AGENTS.md
- https://github.com/steveyegge/beads/blob/main/docs/FAQ.md
- https://github.com/steveyegge/beads/releases

## Open Questions

None blocking. Deferred by YAGNI: Dolt remote choice (only if a concrete multi-machine need appears).
