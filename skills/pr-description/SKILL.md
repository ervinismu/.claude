---
name: pr-description
description: Generate a pull request description with title, summary, and changes for the current branch
argument-hint: [optional extra context]
---

# Generate Pull Request Description

Analyze the current branch and generate a pull request description following the project's PR template and contributing guidelines.

## Instructions

1. **Detect the issue number** from the current branch name (format: `issues/<issue_id>`)
2. **Detect the base branch** by running:
   ```bash
   git rev-parse --verify develop >/dev/null 2>&1 && echo "develop" || echo "main"
   ```
   Use the result as `BASE_BRANCH` for all subsequent commands.
3. **Analyze all changes** on the current branch compared to `BASE_BRANCH`:
   - Run `git log <BASE_BRANCH>..HEAD --oneline` to see all commits
   - Run `git diff <BASE_BRANCH>...HEAD --stat` to see changed files
   - Run `git diff <BASE_BRANCH>...HEAD` to understand the actual code changes
   - Read key changed files if needed to understand context
4. If $ARGUMENTS is provided, incorporate it as additional context
5. **Generate the PR description** following the format below

## PR Title Format

```
[#<issue_id>] <imperative verb> <concise description>
```

- Extract issue ID from branch name
- Use imperative mood (Add, Fix, Update, Refactor, Remove)
- Keep under 70 characters

## PR Description Format

Use this exact structure (matching the project's PR template). Do NOT use table format. Use plain text and bullet points only.

```markdown
## Related Issue
#<issue_id>

## Summary
<1-3 sentences explaining what this PR does and why. Keep it simple and easy to understand. Focus on the purpose and motivation, not implementation details.>

## Changes
- <Change 1: what was done and brief why if not obvious>
- <Change 2>
- <Change 3>
...

## Notes
<Optional: mention any follow-up tasks, migration steps, things reviewers should pay attention to, or potential impacts. Omit this section entirely if there's nothing noteworthy.>
```

## Writing Guidelines

- **Summary**: Write as if explaining to a teammate who hasn't seen the issue. Simple language, no jargon.
- **Changes**: Group related changes together. Each bullet should be a self-contained point. Start with a verb (Add, Update, Fix, Remove, Refactor, Extract, Move).
- **Be specific but concise**: "Add validation for email format in user registration" is better than "Add validation" or "Add email format validation using regex pattern matching in the user model's registration flow".
- **Include helpful context**: If a change might not be obvious from the diff alone, briefly explain the reasoning.
- If there are better suggestions or improvements you notice while reviewing the code, mention them in the Notes section.

## Output

1. First, output the PR title on its own line prefixed with `**PR Title:**`
2. Then output the full PR description body in a code block so the user can easily copy it
3. If you have suggestions for improvements or things you noticed, add them after the description

## Example Output

**PR Title:** [#42] Add email notification for expired contracts

```markdown
## Related Issue
#42

## Summary
Add automatic email notifications when a contract is about to expire. Users will receive a reminder 30 days and 7 days before expiration, helping them take action before the deadline.

## Changes
- Add `ContractExpirationNotificationJob` to check for expiring contracts daily
- Add email templates for 30-day and 7-day reminders
- Update `Contract` model with `expiring_soon` scope for efficient querying
- Add recurring job configuration in `recurring.yml`

## Notes
- The job runs daily at 9:00 AM JST
- Existing contracts that are already within the 30-day window will receive notifications on the next run
```
