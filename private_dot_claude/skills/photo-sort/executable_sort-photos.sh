#!/usr/bin/env bash
# Rename camera files (ORF/ORI/JPG stills, MOV movies, WAV voice notes) to
# YYYY-MM-DD-HHMMSS_<name>.<ext> and move them into MM_YYYY/ inside the same
# folder, dated by when they were shot. Phone photos that arrive already named
# "YYYY-MM-DD HH.MM.SS.jpg" get the camera model as <name> instead.
# Movies are first geotagged from the OI.Share GPS logs in ../gpslog, if any.
# Dry run by default; --apply tags and moves the files. Sidecar .xmp files are
# untouched.
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

# Exit 2 only means every file failed the -if, e.g. all movies already tagged.
exif() {
  local rc=0
  "${exiftool[@]}" "$@" || rc=$?
  ((rc == 2)) && rc=0
  return "$rc"
}

# Geotag movies before they move. The camera tags stills itself while paired
# with OI.Share, but not movies. OI.Share's GPS logs (*.LOG) are copied to a
# gpslog/ folder beside DIR: NMEA fixes in UTC under a header like
# "@Olympus/+0100/+0100". The first offset there matched the camera clock on
# 2026-10-31 (stills geotagged from the log landed within 10 m of the camera's
# own GPS), so it is appended to the local-time CreateDate. Each untagged movie
# is tried against every log; one recorded outside a log's track is left alone
# by that log. -P keeps the modification time, and the original is overwritten
# without an _original copy, because only the metadata atom changes.
# shellcheck disable=SC2016 # the $ expressions are exiftool's, not bash's
untagged=(-ext mov -if 'not $GPSCoordinates')
gpslog=$(dirname -- "$(realpath -- "$dir")")/gpslog
logs=()
[[ -d $gpslog ]] && mapfile -t logs < <(fd -d 1 -t f -e log . "$gpslog" | sort)
if ((${#logs[@]} == 0)); then
  msg="no GPS log in $gpslog, so this movie stays untagged:"
elif ((apply)); then
  for log in "${logs[@]}"; do
    # shellcheck disable=SC2016 # $1:$2 is rg's replacement syntax
    if ! offset=$(head -n 1 "$log" | rg -o -r '$1:$2' '^@[^/]*/([+-]\d\d)(\d\d)'); then
      echo "${log##*/}: no time zone header, so it was not used" >&2
      continue
    fi
    exif -q -q -P -overwrite_original "${untagged[@]}" \
      -geotag "$log" "-geotime<\${CreateDate}$offset" "$dir"
  done
  msg='no GPS fix in the logs, so this movie stays untagged:'
else
  msg="would geotag from ${#logs[@]} log(s) in $gpslog:"
fi
exif -q "${untagged[@]}" -p "$msg '\$Directory/\$FileName'" "$dir" >&2

# TestName prints the planned 'old' --> 'new' moves without touching anything.
tag=TestName
((apply)) && tag=FileName

# Not recursive, so files already in MM_YYYY/ are never revisited; the -if also
# skips anything already carrying the date prefix. %d is the file's own folder,
# %f its name without extension, %le the extension lowercased. exiftool refuses
# to overwrite an existing target, and leaves files that carry no date.
#
# Each month is split by type into MM_YYYY/<ext>/, named after the lowercased
# extension (orf/, jpg/, mov/, and ori/ or wav/ once those turn up). The month
# and the name prefix come from the same tag through DateFmt, because a single
# -d format can't put %le between them. An undefined tag still drops the whole
# assignment, as before.
#
# Later assignments win when their tag exists: stills take DateTimeOriginal,
# movies (which lack it) fall back to QuickTime CreateDate, the start of
# recording. The camera writes that in local time, not the UTC the QuickTime
# spec asks for, so it must not be converted (exiftool's default). The file
# modification time is never used: it reads ~2 hours off after the card copy.
#
# The last assignment covers phone photos already named after their date: the
# original name would only repeat the date, so the model (spaces and slashes
# made hyphens) takes its place. For every other file the expression returns
# undef and the assignment drops out. %-c appends -1, -2 when two phone shots
# share a second; camera files keep refusing collisions so duplicates surface.
#
# Movies warn that DateTimeOriginal is undefined and non-phone files that the
# Model expression returned undef; both are expected, so those lines are
# filtered out. A file with no date at all still warns about CreateDate and
# "No writable tags set". Don't reach for -m instead: it turns a missing tag
# into an empty string, so files get renamed to "_<name>".
#
# Only stderr goes through the filter. exiftool block-buffers stdout but not
# stderr, so with 2>&1 a warning lands mid-way through a move line and the
# filter drops the whole spliced line, hiding moves from the dry run.
# shellcheck disable=SC2016 # the $ expressions are exiftool's, not bash's
phone='$_ = $self->GetValue("FileName") =~ /^\d{4}-\d\d-\d\d \d\d\.\d\d\.\d\d\b/ ? s/[ \/]+/-/gr : undef'

# Target for date tag $1, with $2 after the date in the name.
target() {
  printf '%s' "%d\${$1;DateFmt(\"%m_%Y\")}/%le/\${$1;DateFmt(\"%Y-%m-%d-%H%M%S\")}_$2.%le"
}

status=0
# shellcheck disable=SC2016
{
  "${exiftool[@]}" -ext orf -ext ori -ext jpg -ext mov -ext wav \
    -if 'not $FileName =~ /^\d{4}-\d\d-\d\d-\d{6}_/' \
    "-$tag<$(target CreateDate %f)" \
    "-$tag<$(target DateTimeOriginal %f)" \
    "-$tag<$(target DateTimeOriginal "\${Model;$phone}%-c")" \
    "$dir" 2>&1 1>&3 3>&- |
    { rg -v "Tag 'DateTimeOriginal' not defined|Advanced formatting expression returned undef for 'Model'" >&2 || true; }
} 3>&1 || status=$? # pipefail carries exiftool's status; the filter never fails
exit "$status"
