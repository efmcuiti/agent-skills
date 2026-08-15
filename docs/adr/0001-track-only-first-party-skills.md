# Track only first-party skills; restore third-party ones from a script

This tree mixes skills I wrote with skills installed from `mattpocock/skills` and `vercel-labs/skills`. Tracking all of them meant upstream churn landed in my history and "did I change this?" was only answerable by comparing `.skill-lock.json` folder hashes. Git confirmed every third-party directory was pristine — all were last touched by the baseline commit `e231e00` — so vendoring was buying nothing but noise.

We now git-ignore the third-party directories by explicit name and restore them with `./bootstrap.sh`. `git log` is purely mine, and updating upstream produces no diff beyond `.skill-lock.json`.

## Considered Options

**Keep vendoring everything.** One clone reproduces the whole tree, and it pins me against upstream breaking renames until I choose to move. Rejected because the pin is illusory — I still have to review a large upstream diff to take an update, and I get his churn in my history in exchange.

**Ignore `skills/*` and negate the first-party ones.** Rejected: an allowlist silently ignores *future* first-party skills, which is a much worse failure than forgetting to ignore a future third-party one. A new skill of mine going untracked is invisible until I lose it.

## Consequences

`.skill-lock.json` stays tracked, but as a *receipt* rather than a manifest — it records which upstream version I am on and its folder hash, which is what lets me detect drift later. It is not a `package-lock.json`: the CLI ships `add`, `remove`, `update`, and `list`, but nothing that reinstalls from this file. `experimental_install` restores from a project-scoped `skills-lock.json`, which is a different file in a different scope. Hence `bootstrap.sh`.
