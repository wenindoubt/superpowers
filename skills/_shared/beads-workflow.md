<!-- beads-native: fork-local -->
# Beads Workflow (shared reference)

The superpowers spec→plan→handoff pipeline stores everything in **beads** (`bd`), not markdown.
This doc is referenced by: brainstorming, writing-plans, subagent-driven-development,
executing-plans, session-handoff.

## Ask-first preflight (run before any bd write)

```bash
if [ ! -d .beads ]; then
  echo "No beads database in this repo."   # ASK the human first — never init silently
fi
```

If `.beads/` is missing, STOP and ask the human:
"This repo has no beads database. Initialize one? Suggested prefix: `<short>` (from repo name)."
On yes:
```bash
BD_NON_INTERACTIVE=1 bd init --prefix <short>
bd setup claude   # generates AGENTS.md + CLAUDE.md beads section + hooks
git add .beads AGENTS.md CLAUDE.md .claude/settings.json && git commit -m "chore: init beads"
```
On no: fall back to the skill's pre-beads behavior for this session and tell the human.

## The bead model (one feature)

```
decision bead  (type: decision)   ← brainstorming
  --description : the spec
  --design      : approach + tradeoffs
  --notes       : research findings
   ▲ --spec-id
epic bead  (type: epic)           ← writing-plans
  body: goal, architecture, tech stack
  └── task beads (type: task, --parent epic)   ← one per behavioral unit
       --description : TDD steps as a checklist + code blocks
       --acceptance  : "tests pass + committed"
       deps: bd dep add <dependent> <blocker> --type blocks
       discovered work → bd create ... --deps discovered-from:<id>
```

**Granularity:** a bead is a behavioral unit you could block on, reorder, or assign.
TDD micro-steps (write test / run / implement / run / commit) live in the task body,
NEVER as separate beads.

## Runtime hard rules

These are owned by bd's generated `AGENTS.md` — run `bd prime` for the authoritative list.
Summary: never `bd edit` (use `bd update` w/ flags or `--description=-` stdin); always `--json`
when parsing; `bd update <id> --claim` before work; `bd close <id> --reason "..."` after;
put `(bd-id)` in commit messages; **work is not done until `git push` succeeds**.
