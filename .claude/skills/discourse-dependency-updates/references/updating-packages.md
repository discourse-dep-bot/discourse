# Updating packages

How to find updates, decide which PR they belong in, apply them, and check the result.

## Rules

- **Release age.** Adopt only versions published at least 7 days ago. pnpm enforces this through `minimumReleaseAge` in `pnpm-workspace.yaml`. Bundler does not: check gems with `$SKILL/scripts/release_ages.rb`, and leave a gem whose newest release is younger than that for a later run.
- **Move only what you mean to move.** Use `bundle lock --conservative`, so shared dependencies such as `i18n` stay where they are, and check that `git diff Gemfile.lock` lists only the intended gems.

## Inventory

```bash
bundle outdated --parseable                 # gems, including transitive ones
pnpm outdated -r --format json              # npm packages declared in any workspace package.json
git grep -h -E 'uses: [^ ]+@' .github/workflows | sort | uniq -c   # GitHub Actions
$SKILL/scripts/release_ages.rb gem:excon gem:rubyzip   # gem release ages

# Known advisories
pnpm audit
"$(ruby -e 'print Gem.user_dir')/bin/bundle-audit" check --update
```

`pnpm audit` checks `pnpm-lock.yaml` against the npm registry's advisory database. `bundle-audit` checks `Gemfile.lock` against the public ruby-advisory-db. It is not in the Gemfile, so the setup step installs it for the user. Neither needs access to the repository's security settings.

For a flagged package that is only transitive, `pnpm why -r <pkg>` or `Gemfile.lock` shows what pulls it in. Update it with `pnpm update -r <pkg> --lockfile-only` or `bundle lock --conservative --update <gem>`. If the parent's range does not allow the patched version, update the parent.

`pnpm audit --fix update` re-resolves the whole lockfile to patched versions in one step, but check its diff: it can drop packages that are only installed as peers. Plain `pnpm audit --fix` adds overrides to `pnpm-workspace.yaml`; do not use it.

## Which PR an update goes in

| Kind | What goes in | Title |
| --- | --- | --- |
| `alerts` | Packages that `pnpm audit` or `bundle-audit` flag, where a patched version exists | `DEPS: Bump dependencies with security alerts` |
| `batch` | Every other eligible update: gems, npm packages and GitHub Actions | `DEPS: Bump dependencies` |
| `single` | See below | `DEPS: Bump <name> from <old> to <new>` |

These get a `single` PR:

- Major versions.
- The database driver, the HTTP stack, and JSON parsing (`pg`, `net-http`, `json`, `oj`).
- The JS bundler (`rolldown`).
- Anything that needs code changes beyond updating a spec's expected string.

Some packages must move together, in the same PR: the `@embroider/*` packages, the `@warp-drive/*` packages, and `@atlaskit/pragmatic-drag-and-drop` with its auto-scroll package.

## Read the release notes

Skim each package's release notes across the version range for breaking changes, deprecations and changed defaults. Where something looks relevant, `git grep` for how Discourse uses it. Read more closely for majors and for `single` updates.

The notes are usually in the repository's `CHANGELOG.md` or GitHub releases. Gems often list a `changelog_uri` on rubygems.org. Many npm packages ship `CHANGELOG.md` in their tarball, which helps when the GitHub repository is out of date.

A release-notes concern is a reason to hold the update (see `references/state.md`), with the concern as the reason.

## Apply

Build every PR branch in `../work` from current main (`origin/main`). Apply the updates exactly as recorded in the state, so that a rebuild produces the same result.

**Gems**

```bash
bundle lock --conservative --update gem_a gem_b gem_c
```

To land a version that is not the newest, add a temporary exact pin to the `Gemfile`, run the lock, restore the `Gemfile`, and run `bundle lock` again. The pin is gone and the lockfile keeps the version.

**npm packages**

```bash
pnpm update -r <name>@<version> --lockfile-only   # for each package a workspace package.json declares
pnpm update -r <name> --lockfile-only             # for a package that is only transitive
pnpm dedupe --lockfile-only
$SKILL/scripts/pnpm_lockfile_diff.rb origin/main
```

`pnpm update -r <name>@<version>` locks exactly that version and raises the specifier in every `package.json` that declares the package. Check that exact pins are still exact. `pnpm_lockfile_diff.rb` lists the package versions that were added and removed.

If dedupe moves another package that has its own pending update, raise that package's specifier too, and record it in the PR's updates.

When a `package.json` declares a package for the first time, for example a peer dependency that nothing else installs, use a caret range. A new caret range resolves to the newest eligible version. To land an older one, declare it exact first, run `pnpm install --lockfile-only`, then change it to the caret range and run it again. pnpm keeps the version it has locked, because it satisfies the range.

**GitHub Actions**

Update the version in each `uses:` line. Pushing a change to `.github/workflows` to the fork needs a token with `workflow` scope. If the push is refused, leave the GitHub Actions updates out.

## Commit

One commit per PR, with the title from the table above. Body:

```
### Ruby

- `<name>` from <old> to <new>.
- `<name>` from <old> to <new>. <One sentence on anything a reviewer should know.>

### JavaScript

- `<name>` from <old> to <new>.

### GitHub Actions

- `<action>` from <old> to <new>.

### Held back

- `<name>` <version>: <reason>.

<!-- dependency-updates:<kind> -->
```

Leave out sections with nothing in them. The marker on the last line lets a run find its PRs if the state is lost. When a PR is rebuilt, regenerate the body from the state so that it matches the updates.
