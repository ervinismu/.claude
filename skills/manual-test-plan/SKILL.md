---
name: manual-test-plan
description: Generate a manual test plan for the current branch's changes and publish it as an Artifact (hosted web page with tickable pass/fail checklist). Use when the user says "manual test plan", "test plan", "QA steps", "how do I test this", or asks to write up manual testing after a feature/bug is implemented.
argument-hint: "[optional: issue number, or a scope note like 'only the admin screens']"
---

# Manual Test Plan → Artifact

Produce a concrete, grounded manual test plan for the work on the current branch and publish it as a private Artifact the user can open, share, and tick through while testing.

The plan MUST be derived from the actual diff and issue — never a generic template. Every test case traces to something that changed. This skill is repo-agnostic: detect the project's conventions at runtime rather than assuming any specific stack.

## Step 1: Establish scope

- Current branch: `git branch --show-current`. Extract an issue number if the branch name embeds one (common patterns: `issues/<n>`, `<n>-slug`, `feature/<n>`). If `$ARGUMENTS` is or contains a number, prefer that.
- Determine the **base branch** this work merges into — don't assume. Detect it:
  - `git symbolic-ref refs/remotes/origin/HEAD` (the remote's default branch), or `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` if `gh` is available.
  - If the project uses a develop/main-style model (a `develop` branch exists and the feature branched off it), prefer that. Check the project's contributing docs (README / CONTRIBUTING / CLAUDE.md) if unsure.
- Fetch the issue for acceptance criteria (the source of truth for "expected results"), if the issue tracker is reachable:
  - GitHub: `gh issue view <n> --json number,title,body,state` (no `--repo` needed — `gh` uses the current repo) and `gh issue view <n> --comments` for revised requirements.
  - If `gh` isn't available or the tracker is elsewhere, ask the user for the issue link/text and use it directly.
- Diff against the base branch: `git diff <base>...HEAD --stat`, then `git diff <base>...HEAD` for the files that carry user-facing behavior.
- If `$ARGUMENTS` narrows the scope (e.g. "only the admin screens"), honor it.
- If the branch has no issue, build scope from the diff alone and ask the user for a one-line feature summary if the diff is ambiguous.

## Step 2: Identify what a human must verify

From the diff, list the user-facing surfaces that changed. For each:

- **Screen / entry point + its address** — ALWAYS include how to reach it (a URL path, route, CLI command, or screen name), never just a label. Resolve real IDs/values when you can (a DB console, route listing, or an existing record) so the tester can click straight through; otherwise keep the placeholder visible and give the pattern (e.g. `/orders/:id/edit` with a concrete `.../orders/42/edit` when the ID is known).
- **Role / actor / namespace** — who sees or triggers this. If the change is access-control related, write one test case per affected role, including the *negative* case (the role that must NOT see or edit it).
- **Trigger** — the exact user action (click, form submit, file upload, navigation, background job, API call).

## Step 3: Determine preconditions (do this deliberately)

Preconditions are the setup a tester must complete BEFORE the steps make sense. Work them out from the diff/issue — do not guess, and do not pad.

- **Include a Preconditions section whenever any setup is required** to reach a testable state — a specific login/role, seed or fixture data, a record in a particular state, a feature flag, a migration/setup step, or a prior screen that must be completed first.
- **If a specific test case needs its own prior state** that the global preconditions don't cover, attach a per-case precondition line to that case — don't force everything into one global block.
- **Only omit preconditions when there genuinely are none** (e.g. a public page reachable with no login and no data). If you omit them, it's because none exist — not because you skipped the analysis.
- Draw the concrete building blocks (how to start the app, its local URL, test/seed accounts) from the **project's own docs** (README / CLAUDE.md / seeds) rather than assuming — different repos differ. State the exact command and accounts the tester needs.

## Step 4: Load design guidance (required)

Before writing any HTML, invoke the `artifact-design` skill to calibrate the design. The Artifact tool requires this, and it keeps the page theme-aware, self-contained, and consistent.

## Step 5: Write the test plan page

Write an HTML file to the session scratchpad directory (or the path the user names). Structure:

1. **Title bar** — feature title, issue reference, branch, and base branch. Link the issue if you have a URL (derive it from the repo's remote host — don't hardcode a host/org).
2. **Scope** — 1–2 lines: what changed and what this plan covers. Note anything explicitly **out of scope**.
3. **Preconditions** — render the section from Step 3 as a clear, prominent, checkable setup list (tickable so the tester confirms setup is done before starting). Place it above the test cases. If there are genuinely none, state "No setup required" rather than dropping the heading silently.
4. **Test cases** — one card/row per case. Each has: an ID (TC-1…), the screen/entry point **with its address**, the role, any **case-specific precondition**, numbered steps, and the expected result tied to the issue's acceptance criteria. Render a tickable **Pass / Fail** control per case (plain HTML `<input type="checkbox">` / radios — the page is self-contained, no server).
5. **Edge / negative cases** — validation errors, empty states, permission denials, concurrent edits, long values / overflow, formatting — whatever the diff touches.
6. **Regression checks** — sibling screens or shared code the change could have broken (if the diff touched a shared component/module, list its other callers to spot-check).

Content language: write the plan's prose (headings, instructions, expected results, scope, preconditions) in **English**. Keep literal UI strings the tester will see on screen — banner text, button labels, screen names — quoted verbatim in whatever language the app displays them, since that's what the tester matches against. Keep the instructions concrete and action-oriented.

## Step 6: Publish

Call the `Artifact` tool on the file. Artifacts start **private** — correct for an internal test plan; do not suggest sharing it externally. Set a stable `<title>`, a one-line `description`, and a favicon (e.g. `🧪` or `✅`). Report the returned URL to the user.

If you later regenerate the plan for the same branch, re-publish the **same file path** so it updates in place rather than minting a new URL.

## Conventions to honor

- Screen/entry-point references ALWAYS carry their address (see Step 2).
- No fabricated data presented as real — this is a checklist, not a record.
- Keep it grounded: if the diff is small, a short plan is correct. Do not pad with generic "check the page loads" filler unless load behavior actually changed.
