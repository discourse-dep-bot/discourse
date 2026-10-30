# State

Runs start in a fresh environment, so everything a run must remember lives on the `dep-bot` branch of the bot's fork, `discourse-dep-bot/discourse`. The branch has no history in common with main. It holds:

- `.claude/skills/discourse-dependency-updates/`: this skill.
- `SETUP.md`: how the bot is set up and run, for people.
- `state.json`: what the agent is tracking. This is the source of truth.
- `README.md`: a status page for people, which GitHub shows on the branch. `scripts/state.rb write` regenerates it from `state.json` in the same commit, so it is always current. Never edit it by hand.
- `log/<YYYY-MM-DD>.md`: one entry per run that did something.

Read and write the state only through `scripts/state.rb`, run from the clone of `dep-bot`. It changes `state.json`, `README.md` and the log, and keeps every other file on the branch as it is. People can push changes to the skill at any time. `write` never forces: if another run pushed first, it exits with status 2, and the run must read again and reapply its changes.

## state.json

```json
{
  "version": 1,
  "paused": false,
  "lease": { "run_id": "2026-10-30T14:00:12Z", "expires_at": "2026-10-30T16:00:12Z" },
  "prs": [
    {
      "number": 45301,
      "kind": "batch",
      "branch": "deps/batch-20261030-1400",
      "base_sha": "7457b259b4d...",
      "head_sha": "19f7955bb7c...",
      "status": "draft",
      "replaces": 45122,
      "ready_at": null,
      "comments_seen_at": "2026-10-30T15:20:03Z",
      "updates": [
        { "ecosystem": "gem", "name": "excon", "from": "1.7.2", "to": "1.8.0" },
        { "ecosystem": "npm", "name": "postcss", "from": "8.5.29", "to": "8.5.31", "manifests": ["frontend/asset-processor/package.json"] },
        { "ecosystem": "action", "name": "actions/checkout", "from": "v5", "to": "v6" }
      ],
      "fixes": ["a1b2c3d4e5f..."],
      "ci": { "head_sha": "19f7955bb7c...", "result": "red", "retries": 1, "failing": ["spec/models/theme_field_spec.rb:120"] },
      "bisect": { "set_aside": [{ "ecosystem": "npm", "name": "prosemirror-view", "to": "1.42.6" }] },
      "escalated_at": null,
      "opened_at": "2026-10-30T14:05:40Z"
    }
  ],
  "held": [
    {
      "ecosystem": "gem",
      "name": "capybara-playwright-driver",
      "versions": ">= 0.5.12",
      "reason": "fill_in types every character, which makes system tests 40-80% slower and sends chat messages early",
      "since": "2026-10-19",
      "recheck_after": "2026-11-30"
    }
  ],
  "handed_over": [
    { "number": 45188, "kind": "single", "updates": [{ "ecosystem": "gem", "name": "pg", "from": "1.6.3", "to": "1.7.0" }] }
  ]
}
```

- **`paused`**: when true, runs stop straight away. People set it to pause the bot. Leave it alone.
- **`lease`**: the run that is working. A run that finds an unexpired lease held by another run stops at once. Leases last two hours, so a run that dies does not block later runs for long.
- **`prs`**: the open PRs the agent owns. `status` is `draft` or `ready`. `updates` is the exact list a rebuild applies. `base_sha` is the main commit the branch was built on. `ready_at` is when it was marked ready for review. `replaces` is the ready PR that this draft will supersede, if any. `comments_seen_at` is the time of the newest comment already handled. A PR leaves this list when it is merged or closed.
- **`fixes`**: commits on the branch after the update commit, such as a spec whose expected string changed. A rebuild cherry-picks them.
- **`ci`**: the result for `head_sha`, how many times CI was retried for this set of updates, and the failing tests.
- **`bisect.set_aside`**: updates taken out of the PR when a failure could not be tied to one update. They go into the next PR of the same kind. Most PRs never have this.
- **`held`**: updates not to attempt, with the reason. Retry after `recheck_after`, or when a newer version than `versions` covers is released. A person can add or remove holds by editing the file on the branch.
- **`handed_over`**: PRs that someone else pushed to. The agent no longer touches them, but leaves their updates out of new PRs. Drop an entry once its PR is merged or closed.

## Recovering the state

If `state.json` is missing or wrong, rebuild `prs` from GitHub: open PRs on discourse/discourse by `discourse-dep-bot` whose head branch starts with `deps/` and whose body has a `<!-- dependency-updates:<kind> -->` marker. Read each PR's updates from its commit body. Holds cannot be recovered, so the log is the best source for them.
