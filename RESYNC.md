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

## Shipping a fork-local change (no upstream rebase)

When you edit fork content *without* rebasing onto a new upstream tag, the version in `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` stays the same — and Claude Code caches the plugin **by version** under `~/.claude/plugins/cache/superpowers-dev/superpowers/<version>/`. `marketplace update` pulls the new source into the marketplace clone but does **not** rebuild a same-version cache, so the live plugin keeps running the old code.

So: **bump the patch version in BOTH manifests** before refreshing, then:

```bash
# bump 6.0.x -> 6.0.(x+1) in .claude-plugin/plugin.json AND .claude-plugin/marketplace.json
git commit -am "chore: bump version for <change>" && git push origin main
claude plugin marketplace update superpowers-dev
/reload-plugins   # CC now builds a fresh cache dir for the new version
```

Keep the bump as a patch (`6.0.3 -> 6.0.4`) to stay close to upstream — the next upstream rebase resolves the version line trivially (take upstream's).

## Verifying the research pass survived

```bash
grep -c "Mandatory Web-Research Pass" skills/brainstorming/SKILL.md   # expect 1
grep -c "kiln-web-search-researcher"  skills/writing-plans/SKILL.md   # expect >=1
```
