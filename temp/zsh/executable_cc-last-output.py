#!/usr/bin/env python3
"""Print the last real command's output from a script(1) session transcript.

The interactive shell brackets every command with OSC 133 marks (see the hooks
in ~/.config/zsh/cc.zsh, the file that also defines ccl):

    ESC ] 133 ; C BEL        just before the command runs
    ESC ] 133 ; D BEL        once it has finished

so the bytes between a C/D pair are exactly that command's output. ccl tags its
own region as ESC ] 133 ; C ; ccl BEL and those are skipped here, so running ccl
twice in a row still refers to the same real command.
"""

import re
import sys

TAIL_BYTES = 16 << 20  # transcripts get huge: every TUI redraw lands in them

MARK = re.compile(rb"\x1b\]133;([CD])(?:;([^\x07\x1b]*))?(?:\x07|\x1b\\)")
ESCAPES = re.compile(
    rb"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)"  # OSC, the marks included
    rb"|\x1b\[[0-9;?<>=]*[ -/]*[@-~]"  # CSI
    rb"|\x1b[()][0-9A-Za-z]"  # charset selection
    rb"|\x1b[@-Z\\-_]"  # other two-byte escapes
)

# zsh's promptsp filler, printed just before the prompt (so just before the D
# mark): an inverse "%" padded to the line width, then rubbed out again
PROMPT_SP = re.compile(r"%?[ ]*\r \r\Z")


def last_region(data):
    """Bytes between the final C/D mark pair, ignoring ccl's own regions."""
    end = None
    for m in reversed(list(MARK.finditer(data))):
        kind, tag = m.group(1), m.group(2)
        if end is None:
            if kind == b"D":
                end = m.start()
        elif kind == b"C":
            if tag == b"ccl":
                end = None  # our own invocation: keep looking further back
            else:
                return data[m.end() : end]
    return None


def clean(raw):
    text = ESCAPES.sub(b"", raw).decode("utf-8", "replace")
    text = PROMPT_SP.sub("", text)
    lines = []
    for line in text.split("\n"):
        line = line.rstrip("\r")
        if "\r" in line:  # progress bars: keep what was left on screen
            line = line.rsplit("\r", 1)[1]
        lines.append(line.rstrip())
    return "\n".join(lines).strip("\n")


def main():
    if len(sys.argv) != 2:
        print("usage: cc-last-output.py <transcript>", file=sys.stderr)
        return 2
    with open(sys.argv[1], "rb") as fh:
        fh.seek(0, 2)
        fh.seek(max(0, fh.tell() - TAIL_BYTES))
        data = fh.read()
    region = last_region(data)
    if region is None:
        print("ccl: no completed command found in the transcript", file=sys.stderr)
        return 1
    print(clean(region))
    return 0


if __name__ == "__main__":
    sys.exit(main())
