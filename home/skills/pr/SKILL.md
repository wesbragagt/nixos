---
name: pr
description: Create or update a GitHub pull request for the current branch, committing pending changes first, then monitor the CI checks until they finish and report any failure. Use when the user wants to open a PR, update an existing PR, ship a branch for review, or check PR CI status.
argument-hint: "[optional PR title, base branch, or description context]"
---

# pr

Create or update a GitHub pull request (PR) from the current branch.

Always commit, then push, then create or update the PR.

## Steps

1. Invoke the `/commit` skill if the working tree has changes. Skip if it is clean.
2. Check for an existing PR: `gh pr view --json number,title,body,baseRefName,url 2>/dev/null`
3. Find the branch and the base. Use `git branch --show-current`.
4. Push the branch: `git push -u origin HEAD`
5. Read the change: `git log origin/<base>..HEAD --oneline` and `git diff origin/<base>..HEAD --stat`
6. Write the title. Write the body to a local draft file: `<scratchpad>/pr-body.md`.
7. Create or update the PR with the check and `gh` in one command. See **Body length check**.
8. Monitor the CI checks. See **CI checks**.

## Base branch

Select the base in this order:

1. The base the user gives.
2. `main`, if it exists.
3. `master`, if `main` does not exist.
4. The remote default branch: `git remote show origin | grep 'HEAD branch'`

Stop if the current branch is the base. Tell the user to create a feature branch.

## Push failures

Do not force-push after a rejected push. Tell the user the branch diverged. Ask how to continue.

## Existing PR

If a PR exists:

1. Commit new changes.
2. Push the branch.
3. Write the body again from the full diff against the base, not only the new commits.
4. Run the update command from **Body length check**.
5. Print the PR URL. Say that you updated the description.

## Title

Write a title of 72 characters or less. Use sentence case. Do not use a final period. Name the behavior, not the code.

Good: `Skip handoff when required support docs are not processed`

## Body

Use this structure. Remove an optional section that has no useful content.

```md
## Summary

<The behavior change in plain words. The problem. Why it matters.>

## Behavior change

<What is different after this PR. Include defaults and compatibility.>

## Implementation

<Important decisions and tradeoffs. Not every file.>

## Testing

<Tests, dry-runs, or manual checks.>

## Notes

<Optional: config examples, risks, rollout notes, follow-ups.>
```

## Body rules

<rules>
* Write the body in Simplified Technical English (ASD-STE100).
* Use the simplest correct word. Use one term for one thing.
* Use active voice and present tense. Name the actor.
* Keep each sentence to 25 words or less.
* Do not use idioms, jokes, or figures of speech.
* Keep the full body under 500 words.
* Give the problem before the solution.
* Keep the Summary to one or two short paragraphs.
* Use bullets. Avoid tables.
* Do not list every changed file.
* Do not write a commit list.
* Add a short config example when the PR adds config, flags, statuses, or state rules.
* Explain a meaningful tradeoff in plain words.
* Fold user-supplied context into Summary or Notes.
* Never name an AI tool, a review tool, a reviewer, or a scratch file.
* Never describe the process that made the change. Describe the change.
</rules>

## Body length check

The check runs on the local draft file, never on a published PR. Run `gh pr create` and `gh pr edit` only in the same command as the check, joined with `&&`. The check gates the publish.

Create:

```bash
bash ~/.claude/skills/pr/check-body.sh <scratchpad>/pr-body.md 500 \
  && gh pr create --base <base-branch> --title "<title>" --body-file <scratchpad>/pr-body.md
```

Update:

```bash
bash ~/.claude/skills/pr/check-body.sh <scratchpad>/pr-body.md 500 \
  && gh pr edit --body-file <scratchpad>/pr-body.md
```

The limit is 500 words. Diagrams do not count. The script drops fenced `mermaid`, `plantuml`, `dot`, `graphviz`, and `d2` blocks and markdown images before it counts. Config examples and other code blocks count.

The script exits 1 when the draft is over 500 words. It exits 2 when the draft file is missing or empty. On a non-zero exit, `gh` does not run. Shorten the draft and run the command again. Do not raise the limit to pass.

Edit only the draft file. Publish that same file, so the checked text is the published text.

## CI checks

Monitor the checks after you create or update the PR. Do not stop at the PR URL.

Print the PR URL first. The user must have the link before the wait starts.

### 1. Wait for the checks to register

GitHub needs time to queue the workflows. An immediate query returns no checks.

```bash
sleep 20 && gh pr checks 2>&1
```

Report `No CI checks configured for this repository` and stop when the command says no checks exist. This is a normal result, not a failure.

### 2. Watch until the checks finish

```bash
gh pr checks --watch --fail-fast
```

Run this in the background when the CI run takes more than 10 minutes. The foreground timeout is 10 minutes.

`--fail-fast` stops at the first failure. Do not wait for a green job when another job already failed.

### 3. Report the result

Give the state of each check. Use one line for each.

For a pass:

```
CI: all checks passed (<n> checks, <duration>).
```

For a failure, name the job, then the cause:

```bash
gh run view --log-failed
```

Read the failed log. Report:

1. the job name;
2. the failing step;
3. the first real error line, quoted;
4. the cause in one sentence;
5. the fix in one sentence.

Do not paste the full log. Quote the error line only.

### 4. Stop

Do not fix a CI failure without the user's approval. Report the cause and the proposed fix. Ask.

Exception: the user gave an explicit instruction to fix failures in this session. Then apply the fix, commit, push, and watch the checks again.

Stop after three failed attempts on the same check. Report what you tried. Ask the user.

## Prohibited actions

<rules>
* Do not force-push.
* Do not open a PR from the default branch to itself.
* Do not skip `/commit`.
* Do not use `--draft` unless the user asks.
* Do not mark ready for review or request reviewers unless the user asks.
* Do not report the PR as done while the checks still run.
* Do not merge the PR.
* Do not re-run a failed check to see if it passes the second time. Find the cause.
* Do not run `gh pr create` or `gh pr edit` without `check-body.sh ... &&` in front of it.
</rules>
