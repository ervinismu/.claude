---
name: commit
description: Create a git commit with proper format based on branch naming convention
argument-hint: [optional commit message]
---

# Create Git Commit

Create a git commit following the project's commit message conventions.

## Instructions

1. **Detect the task ID** from the current branch name:
   - Run `git branch --show-current`
   - Extract the task ID from the format `issues/<task_id>`
   - If the branch doesn't match, use `[fix]` as the prefix instead

2. **Analyze changes** to understand what was done:
   - Run `git status` to see all changed/untracked files
   - Run `git diff --cached --stat` to see staged changes
   - Run `git diff --stat` to see unstaged changes
   - If nothing is staged, ask the user which files to stage

3. **Stage files** if needed:
   - Stage only relevant files by name — do NOT use `git add -A` or `git add .`
   - Never stage files that may contain secrets (.env, credentials, keys)
   - Never stage analysis/plan documents (`docs/plans/`) — these are working documents, not feature code
   - Ask the user if unsure which files to include

4. **Run pre-commit checks** on all staged Ruby files:
   - Run `bundle exec rubocop <staged .rb files>` to check for style/security issues
   - If rubocop reports offenses, fix them before proceeding
   - Run `bundle exec brakeman -q --no-pager` for security scan
   - If brakeman reports new warnings related to staged files, fix them before proceeding
   - Run related tests if they exist:
     - For `app/controllers/foo_controller.rb` → run `bin/rails test test/controllers/foo_controller_test.rb`
     - For `app/models/foo.rb` → run `bin/rails test test/models/foo_test.rb`
     - Skip if no matching test file exists
   - Report results to the user. If there are failures, ask whether to proceed or fix first.

5. **Create the commit message**:
   - If $ARGUMENTS is provided, use it as the commit message
   - Otherwise, generate a concise message from the staged changes

## Commit Message Format

```
[#<task_id>] <imperative verb> <short description>
```

Rules:
- Start with `[#<task_id>]` extracted from branch name (e.g., `[#1136]`)
- Use imperative mood: Add, Fix, Update, Refactor, Remove, Extract, Move
- Keep the message short and clear — one line, no body unless truly necessary
- Do NOT add Co-Authored-By or any other trailers
- Do NOT add a commit body unless the user explicitly asks for one
- Do NOT use the word "POC" in commit messages — describe the feature directly
- Do NOT include words like "exploratory" or "proof-of-concept"

Examples:
- `[#42] Add email notification for expired contracts`
- `[#58] Fix N+1 query in talent list`
- `[#100] Refactor condition params into shared concern`
- `[fix] Update README setup instructions`

## Commit Command

Use a HEREDOC to pass the commit message:

```bash
git commit -m "$(cat <<'EOF'
[#<task_id>] Message here
EOF
)"
```

## After Commit

Run `git status` to verify the commit was successful and report the result to the user.

## Important

- Do NOT amend previous commits unless the user explicitly asks
- Do NOT push to remote — only commit locally
- If a pre-commit hook fails, fix the issue and create a NEW commit (do not amend)
- If there are no changes to commit, tell the user — do not create an empty commit
