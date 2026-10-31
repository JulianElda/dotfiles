---
name: photo-sort
description: Rename camera files (raw .ORF/.ORI, .JPG, .MOV movies, .WAV voice notes) and phone JPEGs to YYYY-MM-DD-HHMMSS_<original name or phone model>.<ext> from when they were shot, and move them into MM_YYYY/<ext> folders (orf, jpg, mov, …) inside the same source folder; .MOV movies are first geotagged from OI.Share GPS logs in a sibling gpslog/ folder. Use when Julian points at a folder of photos or videos off the camera or phone (e.g. ~/Pictures/100OLYMP) and asks to rename, sort, organize, file or date them by month.
---

# Photo sort

Turns `<folder>/P9230005.JPG` into `<folder>/09_2026/jpg/2026-09-23-173000_P9230005.jpg`.

Each month folder is split by type into subfolders named after the lowercased
extension: `orf/`, `jpg/`, `mov/`, and `ori/` or `wav/` once those turn up.

The formats come from the Olympus E-M1 Mark III manual:

| Extension | What it is | Date tag used |
|---|---|---|
| `.ORF` | raw still | `DateTimeOriginal` |
| `.JPG` | JPEG still | `DateTimeOriginal` |
| `.ORI` | raw frame saved before a High Res Shot composite | `DateTimeOriginal` (no sample tested yet) |
| `.MOV` | H.264 movie | QuickTime `CreateDate`, the start of recording |
| `.WAV` | voice note attached to a still (up to 30 s) | whichever tag it has (no sample tested yet) |

- Times are taken exactly as the camera recorded them. The camera writes
  local time even into the movie `CreateDate`, which the QuickTime spec says
  should be UTC, so no time-zone conversion is applied. The file's modification
  time is never used.
- The original name is kept, and the extension is lowercased.
- **Phone photos are the exception.** They arrive already named after their
  capture time, like `2026-10-17 16.13.01.JPG` (Sony Xperia `XQ-ES54`, with a
  correct `DateTimeOriginal` and a +02:00 offset). Keeping that name would only
  repeat the date, so the EXIF `Model` takes its place, with spaces and
  slashes turned into hyphens:
  `10_2026/jpg/2026-10-17-161301_XQ-ES54.jpg`. Phone photos are recognised by that
  name pattern, not by brand, so a new phone works too. Two phone shots taken
  in the same second get `-1`, `-2` suffixes.
- **Movies get a location first.** The camera adds GPS to stills itself
  while it is paired with OI.Share, but not to movies. If there is a `gpslog/`
  folder next to the source folder (`Raws/gpslog` beside `Raws/unsorted`), each
  `.MOV` without `GPSCoordinates` gets the position recorded at the start of
  recording, taken from the OI.Share `*.LOG` files there. Those logs are NMEA
  in UTC, under a header like `@Olympus/+0100/+0100`. The first offset in that
  header is added to the movie's local `CreateDate`. On 2026-10-31, stills
  geotagged this way landed within 10 m of the camera's own GPS, while `+02:00`
  and `+00:00` were kilometres off. Altitude reads 0 m, because the log has none
  and the camera's JPGs say the same.
- Only those five extensions, at the top level of the folder, are touched.
  Leave `.xmp` sidecars and every other file where they are: Julian wants it
  that way.

## Steps

1. **Dry run.** Run `~/.claude/skills/photo-sort/sort-photos.sh <folder>`.
   It prints each planned `'old' --> 'new'` move and changes nothing. Summarize
   it for Julian: how many files go to each `MM_YYYY/<ext>` folder, and any warnings.
   Don't paste the whole list. Each untagged movie gets a `would geotag from
   N log(s)` line, or `no GPS log in …` when there is no `gpslog/`. The dry run
   doesn't check whether the movie falls within a log's time span: say how
   many movies would be tagged and from which logs.
2. **Confirm.** Ask before moving anything, unless Julian already said to go
   ahead.
3. **Apply.** Run `~/.claude/skills/photo-sort/sort-photos.sh --apply <folder>`.
4. **Report.** Give the counts from exiftool's summary. Name every file that
   was left behind and say why:
   - `No writable tags set` (just after a `Tag 'CreateDate' not defined`
     line): the file has no date at all. Don't make one up; ask Julian what to
     do. A `.WAV` or `.ORI` showing this is the first real sample of that
     format, so read its tags with `exiftool -a -G1 -s -time:all <file>` and
     update the script and this table.
   - `already exists`: a file with the target name is already in the month
     folder, which is usually a second copy of the same shot. Nothing gets
     overwritten. Compare the two with `cmp` and tell Julian what you found.
     Phone photos never raise this error, because they get a `-1` suffix
     instead. If a dry run shows a phone photo with a `-N` suffix, `cmp` it
     against the file it would sit next to, so a duplicate copy isn't filed
     twice without anyone noticing.
   - `no GPS fix in the logs`: the movie was recorded outside every log's
     track (or in a gap longer than 30 minutes), so it got no location. It is
     still sorted. Tell Julian which movies these are. Don't estimate a
     position.
   - `no time zone header`: a log whose first line isn't `@…/+HHMM/…`. It was
     skipped. Look at its head before guessing an offset.

## Behaviour to rely on

- Running it twice is safe. It doesn't look inside the `MM_YYYY` folders, and
  it skips names that already start with the date prefix. So new files dropped
  into the folder later are sorted on the next run.
- The move is a plain rename: the image bytes and modification time don't
  change. Geotagging rewrites the movie's metadata in place, with no
  `_original` backup and the modification time kept. Movies that already have
  `GPSCoordinates` are never retagged.
- The script exits 1 only on errors, such as `already exists`. A file skipped
  for having no date still exits 0, so read the output instead of relying on
  the exit code.
- Trust `DateTimeOriginal`. Julian checked it against the wall clock on
  2026-10-18 and the camera's local time was correct. Files copied off the card
  show modification times about 2 hours ahead, and the EXIF offset tag reads
  +01:00 all year. Neither affects the names, so don't report the camera clock
  as wrong.
- Files darktable has already imported show as missing in its library after the
  move, because the library stores their old paths. Mention this if Julian edits
  the folder in darktable.
