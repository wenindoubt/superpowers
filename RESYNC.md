# Re-syncing this fork with upstream superpowers

This is a personal fork of [obra/superpowers](https://github.com/obra/superpowers).

**Origin** (`origin`): `git@github.com:wenindoubt/superpowers.git` — this fork.
**Upstream** (`upstream`): `git@github.com:obra/superpowers.git` — the source project.

## The fork's delta

On top of an upstream release tag, this fork adds a **mandatory web-research pass** (via the `kiln-web-search-researcher` subagent) to two skills:

- `skills/brainstorming/SKILL.md` — research pass after clarifying questions, before proposing approaches; persists a `## Research Findings` section in the spec.
- `skills/writing-plans/SKILL.md` — research pass to verify the plan's external dependencies before finalizing.

Plus this `RESYNC.md`. The delta is small and append-style, so rebases are usually clean.

## When to re-sync

Whenever you want a newer upstream release. Watch https://github.com/obra/superpowers/releases — obra ships GPG-signed tags (e.g. `v5.1.0`). No schedule; skipping releases is fine (rebase straight onto the latest tag).

## How to re-sync

Replace `vX.Y.Z` with the actual newest tag.

```bash
cd /Users/wenje/Documents/repositories/superpowers

git fetch upstream --tags        # pull obra's new tags
git tag | sort -V | tail -5      # see the newest available tags

git rebase vX.Y.Z                # replay this fork's commits on top of the new release

# If a conflict appears (only if upstream edited the same 2 skill files):
#   - re-apply the "## Mandatory Web-Research Pass" section / checklist step
#   - git add <file> && git rebase --continue

git push --force-with-lease origin main
```

`--force-with-lease` is required because rebase rewrites history; it is safe here since this fork's `main` is solo.

## After re-syncing: refresh the live plugin

```bash
claude plugin marketplace update superpowers-dev
/reload-plugins
```

(`superpowers-dev` is the marketplace name bundled in `.claude-plugin/marketplace.json`; the live plugin is `superpowers@superpowers-dev`.)

## Verifying the research pass survived

```bash
grep -c "Mandatory Web-Research Pass" skills/brainstorming/SKILL.md   # expect 1
grep -c "kiln-web-search-researcher"  skills/writing-plans/SKILL.md   # expect >=1
```
