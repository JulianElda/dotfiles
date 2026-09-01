#!/bin/bash
# Claude Code status line: cwd, repo name, branch, dirty marker.

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_display="${cwd/#$HOME/\~}"

DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
RED=$'\033[31m'

output="${DIM}${dir_display}${RESET}"

if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  repo_name=$(basename "$(git -C "$cwd" --no-optional-locks rev-parse --show-toplevel)")
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    dirty="${RED}*${RESET}"
  fi

  output="${output} ${DIM}|${RESET} ${CYAN}${repo_name}${RESET} ${DIM}(${RESET}${YELLOW}${branch}${RESET}${dirty}${DIM})${RESET}"
fi

printf '%s\n' "$output"
