#!/usr/bin/env bash
# Claude Code status line
#   🤖 Opus 4.7 │ 📁 awesome-web ⎇ main │ 🧠 ███░░░░░░░ 32% │ 🕌 Asr 15:12 (in 1h05)
#
# Requires: jq, curl, git
# Setup:    chmod +x ~/.claude/statusline.sh, then add to ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# ---------- config ----------
CITY="${PRAYER_CITY:-Yogyakarta}"
COUNTRY="${PRAYER_COUNTRY:-Indonesia}"
METHOD="${PRAYER_METHOD:-20}"   # 20 = KEMENAG (Indonesia). Other methods: https://aladhan.com/calculation-methods
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
mkdir -p "$CACHE_DIR"

# ---------- colors ----------
R=$'\e[0m'; DIM=$'\e[2m'
GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'
CYAN=$'\e[36m'; MAGENTA=$'\e[35m'; BLUE=$'\e[34m'
SEP=" ${DIM}│${R} "

input=$(cat)

# ---------- model ----------
model=$(jq -r '.model.display_name // "Claude"' <<<"$input")

# ---------- project + branch ----------
cwd=$(jq -r '.workspace.current_dir // .cwd // "."' <<<"$input")
project=$(basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
proj_seg="📁 ${BLUE}${project}${R}"
[[ -n "$branch" ]] && proj_seg+=" ⎇ ${MAGENTA}${branch}${R}"

# ---------- context window ----------
used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
if [[ -n "$used" ]]; then
  pct=${used%.*}
  filled=$(( pct / 10 )); empty=$(( 10 - filled ))
  bar=$(printf '%*s' "$filled" '' | tr ' ' '█')$(printf '%*s' "$empty" '' | tr ' ' '░')
  if   (( pct >= 80 )); then c=$RED; warn=" ⚠️"
  elif (( pct >= 50 )); then c=$YELLOW; warn=""
  else                       c=$GREEN; warn=""
  fi
  ctx_seg="🧠 ${c}${bar} ${pct}%${R}${warn}"
else
  ctx_seg="🧠 ${DIM}--${R}"
fi

# ---------- prayer time (Aladhan API, cached per day) ----------
today=$(date +%Y-%m-%d)
pfile="$CACHE_DIR/prayer-${CITY// /_}-${today}.json"
if [[ ! -s "$pfile" ]]; then
  find "$CACHE_DIR" -name 'prayer-*.json' -mtime +1 -delete 2>/dev/null
  # -L: the API redirects to a date-specific URL, so redirects must be followed
  if curl -sfLG --connect-timeout 5 --max-time 10 \
        "https://api.aladhan.com/v1/timingsByCity" \
        --data-urlencode "city=$CITY" --data-urlencode "country=$COUNTRY" \
        --data-urlencode "method=$METHOD" -o "$pfile.tmp" 2>>"$CACHE_DIR/error.log" \
     && jq -e '.data.timings' "$pfile.tmp" >/dev/null 2>&1; then
    mv "$pfile.tmp" "$pfile"
  else
    echo "$(date) fetch failed (city=$CITY country=$COUNTRY method=$METHOD)" >>"$CACHE_DIR/error.log"
    rm -f "$pfile.tmp"
  fi
fi

prayer_seg="🕌 ${DIM}--${R}"
if [[ -s "$pfile" ]]; then
  now=$(date +%H:%M)
  # "Name HH:MM" of the next prayer; falls back to tomorrow's Fajr
  read -r pname ptime < <(jq -r --arg now "$now" '
    .data.timings as $t
    | ["Fajr","Dhuhr","Asr","Maghrib","Isha"]
    | map({name: ., time: ($t[.] | split(" ")[0])})
    | (map(select(.time > $now)) | first) // (.[0] | .name += "+1")
    | "\(.name) \(.time)"' "$pfile")

  to_min() { echo $(( 10#${1%%:*} * 60 + 10#${1##*:} )); }
  diff=$(( $(to_min "$ptime") - $(to_min "$now") ))
  (( diff < 0 )) && diff=$(( diff + 1440 ))
  if (( diff >= 60 )); then left="$(( diff / 60 ))h$(printf '%02d' $(( diff % 60 )))"
  else                      left="${diff}m"
  fi
  pcolor=$CYAN; (( diff <= 15 )) && pcolor=$YELLOW
  prayer_seg="🕌 ${pcolor}${pname/+1/ (tomorrow)} ${ptime}${R} ${DIM}(in ${left})${R}"
fi

printf '%s' "🤖 ${model}${SEP}${proj_seg}${SEP}${ctx_seg}${SEP}${prayer_seg}"
