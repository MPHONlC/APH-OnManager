<!--
Only pull requests touching DATA/KnownLibraries.lua or DATA/KnownAddonVersions.lua need this template.
Keep each PR to ONE entry (one library, or one bumped version) - this makes the automated check clear and keeps review fast.
-->

## What is this PR doing?

- [ ] Adding a brand-new entry
- [ ] Updating an existing entry's version
- [ ] Renaming or removing an entry

## Entry name

<!-- The exact table key, e.g. "LibAlchemy" -->

## Version change (if updating an existing entry)

- Old `requiredVersion` / `displayVersion`:
- New `requiredVersion` / `displayVersion`:

## Source

<!-- Where did requiredVersion/displayVersion come from - the addon's own .addon manifest, ESOUI page, etc.? Link it if you can. -->

---

A bot checks this automatically:

- **New entries** always wait for a human to look them over before merging.
- **Version bumps on an existing entry** get checked for format and that the version isn't going backwards - if they pass, they may be applied for you automatically.
- **Renames or removals** always wait for a human.
