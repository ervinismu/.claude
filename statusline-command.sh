#!/usr/bin/env bash
# Claude Code status line (one line)
#   📁 awesome-web ⎇ issues/4532-confirm ●2 ✚1 ?3 ↑1 │ 🤖 Opus 5.5 · med │ 🧠 ███░░░░░░░ 32% (64k) │ ❄ 16:52 │ 💰 $1.24 +120 −35 │ ⏳ 5h 28% ↻18:30 · 7d 61% ↻Thu 9 │ 🕌 Asr 14:39 (in 2h10)
#
# Requires: jq, curl, git
# Setup:    chmod +x ~/.claude/statusline.sh, then add to ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

# ---------- config ----------
CITY="${PRAYER_CITY:-Yogyakarta}"
COUNTRY="${PRAYER_COUNTRY:-Indonesia}"
METHOD="${PRAYER_METHOD:-20}"   # 20 = KEMENAG (Indonesia). Others: https://aladhan.com/calculation-methods
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
mkdir -p "$CACHE_DIR"

# ---------- colors ----------
R=$'\e[0m'; DIM=$'\e[2m'
GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'
CYAN=$'\e[36m'; MAGENTA=$'\e[35m'; BLUE=$'\e[34m'
SEP=" ${DIM}│${R} "

# color by percentage: green <50, yellow <80, red >=80
pct_color() {
  local p=${1%.*}
  if   (( p >= 80 )); then printf '%s' "$RED"
  elif (( p >= 50 )); then printf '%s' "$YELLOW"
  else                     printf '%s' "$GREEN"
  fi
}
# 10-char bar for a percentage
bar() {
  local p=${1%.*} f e
  f=$(( p / 10 )); e=$(( 10 - f ))
  local out="" i
  for (( i = 0; i < f; i++ )); do out+='█'; done
  for (( i = 0; i < e; i++ )); do out+='░'; done
  printf '%s' "$out"
}
# 64230 -> 64k
fmt_k() { local n=${1%.*}; (( n >= 1000 )) && printf '%dk' $(( n / 1000 )) || printf '%d' "$n"; }

input=$(cat)

# ---------- parse input (single jq call; "-" marks a missing value) ----------
IFS=$'\t' read -r model cwd used tokens cost added removed \
    five five_reset week week_reset effort fast cache_warm cache_exp < <(jq -r '
  [ .model.display_name // "Claude",
    .workspace.current_dir // .cwd // ".",
    .context_window.used_percentage,
    (.context_window.current_usage
      | if . then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) else null end),
    .cost.total_cost_usd,
    .cost.total_lines_added // 0,
    .cost.total_lines_removed // 0,
    .rate_limits.five_hour.used_percentage,
    .rate_limits.five_hour.resets_at,
    .rate_limits.seven_day.used_percentage,
    .rate_limits.seven_day.resets_at,
    .effort.level,
    .fast_mode,
    .prompt_cache.warm,
    .prompt_cache.expires_at
  ] | map(if . == null or . == "" then "-" else tostring end) | @tsv' <<<"$input" 2>/dev/null)
for v in model cwd used tokens cost added removed five five_reset week week_reset \
         effort fast cache_warm cache_exp; do
  [[ ${!v} == "-" ]] && printf -v "$v" ''
done
[[ -z "$model" ]] && model="Claude"
[[ -z "$cwd"   ]] && cwd="."
printf -v now_epoch '%(%s)T' -1

# ---------- model + effort + fast mode ----------
model_seg="🤖 ${model}"
case "$effort" in
  medium) effort="med" ;;
esac
[[ -n "$effort" ]] && model_seg+=" ${DIM}·${R} ${effort}"
[[ "$fast" == "true" ]] && model_seg+=" ${YELLOW}⚡${R}"

# ---------- project + branch + git state ----------
project=$(basename "$cwd")
proj_seg="📁 ${BLUE}${project}${R}"

if branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null); then
  proj_seg+=" ⎇ ${MAGENTA}${branch}${R}"

  # working tree: ●modified ✚staged ?untracked
  status=$(git -C "$cwd" status --porcelain 2>/dev/null)
  if [[ -n "$status" ]]; then
    staged=$(grep -c '^[MADRC]' <<<"$status")
    modified=$(grep -c '^.[MD]' <<<"$status")
    untracked=$(grep -c '^??' <<<"$status")
    git_seg=""
    (( modified  > 0 )) && git_seg+=" ${YELLOW}●${modified}${R}"
    (( staged    > 0 )) && git_seg+=" ${GREEN}✚${staged}${R}"
    (( untracked > 0 )) && git_seg+=" ${DIM}?${untracked}${R}"
    proj_seg+="$git_seg"
  fi

  # ahead/behind upstream
  if ab=$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
    behind=${ab%%	*}; ahead=${ab##*	}
    (( ahead  > 0 )) && proj_seg+=" ${CYAN}↑${ahead}${R}"
    (( behind > 0 )) && proj_seg+=" ${RED}↓${behind}${R}"
  else
    proj_seg+=" ${DIM}⇡?${R}"   # no upstream set
  fi
fi

# ---------- context window ----------
ctx_seg=""
if [[ -n "$used" ]]; then
  tok_str=""; [[ -n "$tokens" && "$tokens" != "0" ]] && tok_str=" ${DIM}($(fmt_k "$tokens"))${R}"
  warn=""; (( ${used%.*} >= 80 )) && warn=" ⚠️"
  ctx_seg="🧠 $(pct_color "$used")$(bar "$used") ${used%.*}%${R}${tok_str}${warn}"
fi

# ---------- prompt cache: clock time it expires (stays correct while idle) ----------
cache_seg=""
if [[ -n "$cache_exp" ]]; then
  if [[ "$cache_warm" == "true" ]] && (( ${cache_exp%.*} > now_epoch )); then
    printf -v exp_hm '%(%H:%M)T' "${cache_exp%.*}"
    ccolor=$CYAN; (( ${cache_exp%.*} - now_epoch <= 300 )) && ccolor=$YELLOW
    cache_seg="❄ ${ccolor}${exp_hm}${R}"
  else
    cache_seg="❄ ${DIM}cold${R}"
  fi
fi

# ---------- session cost + lines changed ----------
cost_seg=""
[[ -n "$cost" ]] && printf -v cost_seg '💰 $%.2f' "$cost"
if (( ${added:-0} > 0 || ${removed:-0} > 0 )); then
  cost_seg+="${cost_seg:+ }${GREEN}+${added}${R} ${RED}−${removed}${R}"
fi

# ---------- rate limits (Pro/Max; empty until first response) ----------
# epoch -> " ↻18:30" if today, else " ↻Thu 9"
fmt_reset() {
  [[ -z "$1" ]] && return
  local day today hm
  printf -v day '%(%F)T' "${1%.*}"; printf -v today '%(%F)T' -1
  if [[ "$day" == "$today" ]]; then printf -v hm '%(%H:%M)T' "${1%.*}"
  else                              printf -v hm '%(%a %-d)T' "${1%.*}"
  fi
  printf ' %s↻%s%s' "$DIM" "$hm" "$R"
}
limit_seg=""
[[ -n "$five" ]] && limit_seg+="${DIM}5h${R} $(pct_color "$five")${five%.*}%${R}$(fmt_reset "$five_reset")"
[[ -n "$week" ]] && limit_seg+="${limit_seg:+ ${DIM}·${R} }${DIM}7d${R} $(pct_color "$week")${week%.*}%${R}$(fmt_reset "$week_reset")"
[[ -n "$limit_seg" ]] && limit_seg="⏳ ${limit_seg}"

# ---------- prayer time (Aladhan API, cached per day) ----------
today=$(date +%Y-%m-%d)
pfile="$CACHE_DIR/prayer-${CITY// /_}-${today}.json"
failmark="$CACHE_DIR/prayer-fetch-failed"
# after a failed fetch, wait 30 min before retrying so offline renders stay fast
recent_fail=$(find "$failmark" -mmin -30 2>/dev/null)
if [[ ! -s "$pfile" && -z "$recent_fail" ]]; then
  find "$CACHE_DIR" -name 'prayer-*.json' -mtime +1 -delete 2>/dev/null
  # -L: the API redirects to a date-specific URL, so redirects must be followed
  if curl -sfLG --connect-timeout 5 --max-time 10 \
        "https://api.aladhan.com/v1/timingsByCity" \
        --data-urlencode "city=$CITY" --data-urlencode "country=$COUNTRY" \
        --data-urlencode "method=$METHOD" -o "$pfile.tmp" 2>>"$CACHE_DIR/error.log" \
     && jq -e '.data.timings' "$pfile.tmp" >/dev/null 2>&1; then
    mv "$pfile.tmp" "$pfile"
    rm -f "$failmark"
  else
    echo "$(date) fetch failed (city=$CITY country=$COUNTRY method=$METHOD)" >>"$CACHE_DIR/error.log"
    rm -f "$pfile.tmp"
    touch "$failmark"
  fi
fi

prayer_seg=""
if [[ -s "$pfile" ]]; then
  now=$(date +%H:%M)
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

# ---------- output (one line) ----------
# empty segments are skipped so no dangling separators
out=""
for seg in "$proj_seg" "$model_seg" "$ctx_seg" "$cache_seg" "$cost_seg" "$limit_seg" "$prayer_seg"; do
  [[ -n "$seg" ]] && out+="${out:+$SEP}${seg}"
done
printf '%s' "$out"
