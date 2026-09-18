#!/bin/bash
# Claude Code status line: model + effort, 5h/7d usage, cwd, branch, dirty marker.

input=$(cat)

IFS=$'\x1f' read -r cwd model effort fast thinking pct5h pct7d < <(
  jq -j '[
    .workspace.current_dir,
    (.model.display_name // ""),
    (.effort.level // ""),
    (if .fast_mode then "fast" else "" end),
    (if .thinking.enabled == false then "nothink" else "" end),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.seven_day.used_percentage // "")
  ] | map(tostring) | join("\u001f")' <<<"$input"
)

dir_display="${cwd/#$HOME/\~}"

DIM=$'\033[2m'
BLUE=$'\033[34m'
RESET=$'\033[0m'
BRBLACK=$'\033[90m'
RED=$'\033[31m'
CLAUDE=$'\033[38;2;218;119;86m' # #da7756, Claude Code's own accent
GREEN=$'\033[32m'

sep="${DIM}|${RESET}"

# "NN%" for one window, empty when the field is absent -- rate_limits is omitted
# on API-key/Bedrock/Vertex sessions and until the first API response of the
# session carries the ratelimit headers.
usage_pct() {
  [ -z "$1" ] && return
  printf '%.0f%%' "$1"
}

usage=""
for part in "$(usage_pct "$pct5h")" "$(usage_pct "$pct7d")"; do
  [ -z "$part" ] && continue
  [ -n "$usage" ] && usage="${usage}/"
  usage="${usage}${part}"
done

output=""

if [ -n "$model" ]; then
  output="${CLAUDE}${model}${RESET}"
  [ -n "$effort" ] && output="${output}${DIM}:${RESET}${CLAUDE}${effort}${RESET}"
  [ -n "$fast" ] && output="${output} ${GREEN}⚡${RESET}"
  [ -n "$thinking" ] && output="${output} ${DIM}(nothink)${RESET}"
fi

if [ -n "$usage" ]; then
  [ -n "$output" ] && output="${output} "
  output="${output}${DIM}[${RESET}${BRBLACK}${usage}${RESET}${DIM}]${RESET}"
fi

[ -n "$output" ] && output="${output} ${sep} "

output="${output}${BLUE}${dir_display}${RESET}"

if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty="${RED}*${RESET}"
  fi

  output="${output} ${sep} ${BRBLACK}${branch}${RESET}${dirty}"
fi

printf '%s\n' "$output"
