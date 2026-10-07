# .claude

<img width="4032" height="2686" alt="development-workflow" src="https://github.com/user-attachments/assets/80689a5e-1bee-48c5-b9f8-d2e20ac29622" />

## Status line

[`statusline-command.sh`](statusline-command.sh) renders a single-line status bar for Claude Code:

```
📁 awesome-web ⎇ issues/4532-confirm ●2 ✚1 ?3 ↑1 │ 🤖 Opus 5.5 · med ⚡ │ 🧠 ███░░░░░░░ 32% (64k) │ ❄ 16:52 │ 💰 $1.24 +120 −35 │ ⏳ 5h 28% ↻18:30 · 7d 61% ↻Thu 9 │ 🕌 Asr 14:39 (in 2h10)
```

Segments with no data are hidden, so early in a session the line is shorter.

### Segments

| Segment | Example | Meaning |
|---|---|---|
| 📁 Project | `📁 awesome-web` | Name of the current working directory. |
| ⎇ Branch | `⎇ issues/4532-confirm` | Current git branch, or the short commit id on a detached HEAD. Hidden outside a git repo. |
| Working tree | `●2 ✚1 ?3` | `●` modified files, `✚` staged files, `?` untracked files. Each is hidden when zero. |
| Upstream | `↑1 ↓2` | `↑` commits to push, `↓` commits to pull. Hidden when in sync or when the branch has no upstream. |
| Git timeout | `⎇ main …` | `git status` took longer than 0.5s (very large repo), so only the branch is shown. |
| 🤖 Model | `🤖 Opus 5.5 · med ⚡` | Active model, then the effort level (`low`, `med`, `high`, …). `⚡` means fast mode is on. |
| 🧠 Context | `🧠 ███░░░░░░░ 32% (64k)` | How full the context window is, with tokens in use. `⚠️` appears at 80% or more. |
| ❄ Prompt cache | `❄ 16:52` | Clock time the prompt cache expires. Send the next message before then and the conversation is read from cache cheaply; after it, the whole context is reprocessed at full cost and counts more against your usage limits. `❄ cold` means it has already expired. |
| 💰 Cost | `💰 $1.24 +120 −35` | Session cost in USD (API-equivalent on a subscription), then lines added and removed by Claude this session. |
| ⏳ Usage limits | `⏳ 5h 28% ↻18:30 · 7d 61% ↻Thu 9` | Pro/Max usage of the 5-hour and 7-day limits, each followed by when it resets: a clock time if today, otherwise weekday and day of month. Appears after the first response. |
| 🕌 Prayer time | `🕌 Asr 14:39 (in 2h10)` | Next prayer and time remaining, from the [Aladhan API](https://aladhan.com/prayer-times-api). Shows `(tomorrow)` after Isha. |

### Colors

| Color | Used for |
|---|---|
| 🟢 Green | Context / usage below 50%, staged files, lines added |
| 🟡 Yellow | Context / usage 50–79%, modified files, prompt cache expiring within 5 min, prayer within 15 min |
| 🔴 Red | Context / usage 80% or more, commits behind upstream, lines removed |
| 🔵 Cyan | Commits ahead of upstream, prompt cache time, upcoming prayer |

### Setup

Requires `jq`, `curl` and `git`, plus an emoji font (e.g. `noto-fonts-emoji`) for the icons to render.

```sh
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline-command.sh" }
}
```

### Configuration

Set these environment variables to change the prayer time location:

| Variable | Default | Description |
|---|---|---|
| `PRAYER_CITY` | `Yogyakarta` | City name |
| `PRAYER_COUNTRY` | `Indonesia` | Country name |
| `PRAYER_METHOD` | `20` (KEMENAG) | [Calculation method](https://aladhan.com/calculation-methods) |

Prayer times are fetched once a day and cached in `~/.cache/claude-statusline/`. If the fetch fails (e.g. offline), it is retried after 30 minutes rather than on every refresh; errors are logged to `error.log` in the same directory.
