<!-- beads-native: fork-local -->
# Beads Workflow (shared reference)

The superpowers spec→plan→handoff pipeline stores everything in **beads** (`bd`), not markdown.
This doc is referenced by: brainstorming, writing-plans, subagent-driven-development,
executing-plans, cmux-handoff.

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
BD_NON_INTERACTIVE=1 bd init --prefix <short>   # auto-wires a Dolt remote to origin if the repo has one
bd setup claude   # generates AGENTS.md + CLAUDE.md beads section + hooks
git add AGENTS.md CLAUDE.md .claude/settings.json && git commit -m "chore: init beads"
bd dolt push      # publish the bead DB to refs/dolt/data on origin (remote tracking)
```
Do NOT `git add .beads/` — it is Dolt-native and stays out of git (`bd init` excludes it). Beads sync to GitHub through the hidden `refs/dolt/data` ref, never by committing `.beads` or `issues.jsonl`. If origin is **public**, `bd dolt push` publishes the bead text — fine for issue tracking, not for secrets; skip it (or point the remote elsewhere with `bd dolt remote add origin <url>`) if that's a problem.
On no: fall back to the skill's pre-beads behavior for this session and tell the human.

## Remote sync (GitHub)

Beads live in the local embedded Dolt DB and back up to GitHub on `refs/dolt/data`, a ref
namespace separate from `refs/heads`/`refs/tags`, so it never touches your branches:

- `bd dolt push` — publish/refresh the DB. Run at session end, alongside `git push`.
- `bd dolt pull` — pull bead changes from another machine or teammate.
- Fresh clone → `bd bootstrap` restores every issue from `refs/dolt/data` (a plain `git clone` does not fetch it).
- `bd init` on a repo with a git origin auto-wires this remote; otherwise add it once:
  `bd dolt remote add origin git+ssh://git@github.com/<org>/<repo>.git`.

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
put `(bd-id)` in commit messages; **work is not done until `git push` AND `bd dolt push` succeed** (code + beads both synced to the remote).
