---
name: photo-sort
description: Rename camera files (raw .ORF/.ORI, .JPG, .MOV movies, .WAV voice notes) and phone JPEGs to YYYY-MM-DD-HHMMSS_<original name or phone model>.<ext> from when they were shot, and move them into MM_YYYY folders inside the same source folder. Use when Julian points at a folder of photos or videos off the camera or phone (e.g. ~/Pictures/100OLYMP) and asks to rename, sort, organize, file or date them by month.
---

# Photo sort

Turns `<folder>/P9230005.JPG` into `<folder>/09_2026/2026-09-23-173000_P9230005.jpg`.

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
  `10_2026/2026-10-17-161301_XQ-ES54.jpg`. Phone photos are recognised by that
  name pattern, not by brand, so a new phone works too. Two phone shots taken
  in the same second get `-1`, `-2` suffixes.
- Only those five extensions, at the top level of the folder, are touched.
  Leave `.xmp` sidecars and every other file where they are: Julian wants it
  that way.

## Steps

1. **Dry run.** Run `~/.claude/skills/photo-sort/sort-photos.sh <folder>`.
   It prints each planned `'old' --> 'new'` move and changes nothing. Summarize
   it for Julian: how many files go to each `MM_YYYY` folder, and any warnings.
   Don't paste the whole list.
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

## Behaviour to rely on

- Running it twice is safe. It doesn't look inside the `MM_YYYY` folders, and
  it skips names that already start with the date prefix. So new files dropped
  into the folder later are sorted on the next run.
- The move is a plain rename: the image bytes and modification time don't
  change.
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
