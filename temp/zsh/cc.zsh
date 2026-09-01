# ccb / ccm / ccl — run a command (or reach back for the last one) and put the
# command line plus its output on the clipboard, ready to paste into Claude Code.
#
# Sourced from ~/.zshrc, and it has to be sourced EARLY:
#   - the transcript block below re-execs the shell via script(1)
#   - _cc_mark_done must be registered before starship's precmd hook, so that
#     it still sees the real exit status
#
# Companion: cc-last-output.py in this directory, the extractor ccl uses.
# ($0 is this file only while it is being sourced, so pin the dir now.)
_CC_DIR=${0:A:h}

# session transcript: script(1) records everything the terminal shows, so ccl
# can copy back the output of a command that was already run plainly
if [[ -o interactive && -z $CC_TRANSCRIPT && -t 1 ]] && (( $+commands[script] )); then
  _cc_dir=${TMPDIR:-/tmp}/zsh-transcript-$UID
  mkdir -p -m 700 $_cc_dir
  for _cc_old in $_cc_dir/*.log(N); do        # leftovers from shells that crashed
    kill -0 ${${_cc_old:t}:r} 2>/dev/null || rm -f -- $_cc_old
  done
  unset _cc_old _cc_dir
  export CC_TRANSCRIPT=${TMPDIR:-/tmp}/zsh-transcript-$UID/$$.log
  exec script -qef "$CC_TRANSCRIPT"   # same pid, so the name still matches
fi

# OSC 133 command marks: invisible in the terminal, but they bracket each
# command's output in the transcript, which is how ccl finds it again
if [[ -n $CC_TRANSCRIPT ]]; then
  autoload -Uz add-zsh-hook

  _cc_mark_exec() {
    CC_CUR_CMD=$1
    # tag ccl's own region so the extractor skips it, and two ccl in a row
    # still refer to the same real command
    if [[ $1 == ccl(|[[:space:]]*) ]]; then
      print -rn -- $'\e]133;C;ccl\a'
    else
      print -rn -- $'\e]133;C\a'
    fi
  }

  # runs ahead of starship's precmd, so it has to hand the real status on
  _cc_mark_done() {
    local ret=$?
    [[ $CC_CUR_CMD != ccl(|[[:space:]]*) ]] && CC_LAST_CMD=$CC_CUR_CMD CC_LAST_STATUS=$ret
    print -rn -- $'\e]133;D\a'
    return $ret
  }

  _cc_transcript_rm() { rm -f -- "$CC_TRANSCRIPT" }

  add-zsh-hook preexec _cc_mark_exec
  add-zsh-hook precmd  _cc_mark_done
  add-zsh-hook zshexit _cc_transcript_rm
fi

# clipboard backend: first available wins
_cc_clip() {
  if   command -v wl-copy  >/dev/null 2>&1; then wl-copy
  elif command -v xclip    >/dev/null 2>&1; then xclip -selection clipboard
  elif command -v clip.exe >/dev/null 2>&1; then clip.exe
  elif command -v pbcopy   >/dev/null 2>&1; then pbcopy
  else printf '\033]52;c;%s\a' "$(base64 | tr -d '\n')"   # OSC 52 fallback
  fi
}

# _cc_emit <fenced:0|1> <command-line> <output> <status> — format to stdout
_cc_emit() {
  emulate -L zsh
  local md=$1 cmd=$2 out=$3 ret=$4 fence
  {
    if (( md )); then
      fence='```'
      # outgrow any backtick run in the output, so nested fences can't leak
      while [[ $out == "$fence"* || $out == *$'\n'"$fence"* ]]; do fence+='`'; done
      print -r -- "${fence}console"
    fi
    print -r -- "\$ $cmd"
    print -r -- "$out"
    (( ret )) && print -r -- "[exit status: $ret]"
    (( md )) && print -r -- "$fence"
  }
  return 0   # the (( md )) test above is the last command, and it fails when md=0
}

# _cc_run <fenced:0|1> <command...> — run it, show it, copy it
_cc_run() {
  emulate -L zsh
  local md=$1; shift
  local tmp ret out
  tmp=$(mktemp) || return 1
  "$@" 2>&1 | tee "$tmp"          # pipeline in THIS shell, so pipestatus is real
  ret=$pipestatus[1]
  out=$(sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g' "$tmp")   # strip ANSI colors
  rm -f "$tmp"
  _cc_emit $md "${(j: :)${(q-)@}}" "$out" $ret | _cc_clip
  return $ret
}

ccb() { _cc_run 0 "$@" }   # bare:     command + output
ccm() { _cc_run 1 "$@" }   # markdown: fenced ```console block

# where ccl -f drops the output; CLAUDE.md points Claude Code at this path
export CC_LAST_OUTPUT_FILE=/tmp/cc-last-output.txt

# ccl [-b] [-f] — pull the PREVIOUS command's output back out of the transcript,
# for when you ran it plainly and only afterwards wanted it
#   -b  bare, no ```console fence
#   -f  write to $CC_LAST_OUTPUT_FILE instead of the clipboard; always bare,
#       since Claude Code reads that file directly and never pastes it anywhere
ccl() {
  emulate -L zsh
  local md=1 sink=clip
  while [[ $1 == -* ]]; do
    case $1 in
      -b) md=0 ;;
      -f) sink=file ;;
      -h|--help) print -r -- 'usage: ccl [-b] [-f]'; return 0 ;;
      *)  print -ru2 -- "ccl: unknown option $1"; return 2 ;;
    esac
    shift
  done
  if [[ -z $CC_TRANSCRIPT || ! -r $CC_TRANSCRIPT ]]; then
    print -ru2 -- "ccl: this shell is not being recorded by script(1)"
    return 1
  fi
  local out
  out=$(python3 $_CC_DIR/cc-last-output.py "$CC_TRANSCRIPT") || return 1
  if [[ $sink == file ]]; then
    _cc_emit 0 "${CC_LAST_CMD:-?}" "$out" ${CC_LAST_STATUS:-0} > $CC_LAST_OUTPUT_FILE || return 1
    print -r -- "ccl: wrote $CC_LAST_OUTPUT_FILE"
  else
    _cc_emit $md "${CC_LAST_CMD:-?}" "$out" ${CC_LAST_STATUS:-0} | _cc_clip
  fi
}
