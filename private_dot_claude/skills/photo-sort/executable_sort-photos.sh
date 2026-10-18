#!/usr/bin/env bash
# Rename camera files (ORF/ORI/JPG stills, MOV movies, WAV voice notes) to
# YYYY-MM-DD-HHMMSS_<name>.<ext> and move them into MM_YYYY/ inside the same
# folder, dated by when they were shot.
# Dry run by default; --apply moves the files. Sidecar .xmp files are untouched.
set -euo pipefail

usage() {
  echo "usage: ${0##*/} [--apply] DIR" >&2
  exit 2
}

apply=0
if [[ ${1:-} == --apply ]]; then
  apply=1
  shift
fi
[[ $# -eq 1 && -d $1 ]] || usage
dir=$1

# exiftool lands on PATH with the NixOS rebuild; until then run it from nixpkgs.
if command -v exiftool >/dev/null; then
  exiftool=(exiftool)
else
  exiftool=(nix run nixpkgs#exiftool --)
fi

# TestName prints the planned 'old' --> 'new' moves without touching anything.
tag=TestName
((apply)) && tag=FileName

# Not recursive, so files already in MM_YYYY/ are never revisited; the -if also
# skips anything already carrying the date prefix. %d is the file's own folder,
# %f its name without extension, %le the extension lowercased. exiftool refuses
# to overwrite an existing target, and leaves files that carry no date.
#
# Later assignments win when their tag exists: stills take DateTimeOriginal,
# movies (which lack it) fall back to QuickTime CreateDate, the start of
# recording. The camera writes that in local time, not the UTC the QuickTime
# spec asks for, so it must not be converted (exiftool's default). The file
# modification time is never used: it reads ~2 hours off after the card copy.
#
# Every movie warns "Tag 'DateTimeOriginal' not defined", so that line is
# filtered out. A file with no date at all still warns about CreateDate and
# "No writable tags set". Don't reach for -m instead: it turns a missing tag
# into an empty string, so files get renamed to "_<name>".
# shellcheck disable=SC2016 # the $ expressions are exiftool's, not bash's
"${exiftool[@]}" -ext orf -ext ori -ext jpg -ext mov -ext wav \
  -if 'not $FileName =~ /^\d{4}-\d\d-\d\d-\d{6}_/' \
  -d '%m_%Y/%Y-%m-%d-%H%M%S' \
  "-$tag"'<%d${CreateDate}_%f.%le' \
  "-$tag"'<%d${DateTimeOriginal}_%f.%le' \
  "$dir" 2>&1 | { rg -v "Tag 'DateTimeOriginal' not defined" || true; }
exit "${PIPESTATUS[0]}"
