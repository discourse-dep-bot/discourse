# discourse-dep-bot

`discourse-dep-bot` keeps the dependencies of [discourse/discourse](https://github.com/discourse/discourse) up to date. It opens draft PRs from this fork, works on them until CI is green, and then marks them ready for review. People review and merge them.

- **How it works:** [`.claude/skills/discourse-dependency-updates/SKILL.md`](.claude/skills/discourse-dependency-updates/SKILL.md).
- **What it is doing now:** [`README.md`](README.md), which is regenerated on every run.

## One-time setup

1. **Create the fork.** As `discourse-dep-bot`, run `gh repo fork discourse/discourse --clone=false`.
2. **Turn off GitHub Actions on the fork** (Settings → Actions → General). Pushes to `deps/` branches should not run CI on the fork. CI runs on the PRs in discourse/discourse.
3. **Push this branch** to the fork as `dep-bot`, and make it the fork's default branch, so that the fork's front page shows the status.
4. **Give the bot a token** that can push to its fork and open, comment on and close PRs on discourse/discourse. The token also needs the `workflow` scope, or the bot leaves GitHub Actions updates out of its PRs.
5. **Let its CI run.** discourse/discourse asks a maintainer to approve workflow runs for PRs from outside contributors. Until the bot no longer needs approval, someone has to click "Approve and run" on its PRs. The bot escalates on a PR that has waited more than a day.
6. **Add `bundler-audit`** to the development group of discourse/discourse's `Gemfile`. The bot runs `bundle exec bundle-audit`.

## Running it

`bin/run-loop` runs the bot every 15 minutes, each time in a fresh directory, until it is stopped. It needs git, `gh`, `claude`, Ruby with Bundler, and Node with pnpm, and a file holding the bot's token:

```bash
bin/run-loop /path/to/token.txt
```

Each run clones this branch into a temporary directory and starts `claude -p` there, so the agent finds the skill. The token is passed through the environment only, and commits are made as `discourse-dep-bot`. Each run's output goes to `~/.local/state/dep-bot/`.

Runs that overlap are safe. A run that finds another one in progress stops at once.

## Steering it

- **Comment on its PRs.** It answers questions, and drops, holds or pins updates when asked. It acts only on comments from people with write access to discourse/discourse.
- **Edit `state.json` on this branch,** for example to add or remove an entry in `held`.
- **Pause it** by setting `"paused": true` in `state.json`. Runs stop straight away until it is removed.
