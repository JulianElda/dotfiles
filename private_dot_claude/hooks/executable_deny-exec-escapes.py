#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""PreToolUse guard: deny the exec-escape flags on broadly-allowed search tools.

`permissions.allow` grants `Bash(rg *)` and `Bash(fd *)`. Their trailing wildcard also
approves any option inserted at that position, and both tools can run arbitrary commands:

    rg --pre=CMD            runs CMD as a preprocessor for every searched file
    rg --hostname-bin=CMD   runs CMD to determine the hostname
    fd -x / -X / --exec     runs a command per match (or once, batched)

No permission-rule shape can express "rg but not --pre", so a hook is the only place that
gap closes. Secret *reading* is deliberately out of scope: the deny list covers the Read
tool and Claude Code's own protection already blocks Bash whose output would carry a
secret, so duplicating it here would only add false positives.

Reads the PreToolUse payload on stdin. Silence means allow; a deny prints one JSON object.

This is a speed bump, not a boundary. It matches flag spellings in the command string, so
obfuscation (`--pr''e`, a variable holding the flag, a wrapper script) defeats it. It is
worth having because it catches the inadvertent case and the casual injection, cheaply.
"""

import json
import re
import sys

# Prefixes to strip before identifying the command a segment actually runs.
WRAPPERS = frozenset(
    {"sudo", "command", "nohup", "nice", "stdbuf", "env", "time", "xargs"}
)
WRAPPERS_WITH_ARG = frozenset({"timeout"})

# Long flags that take a command. The lookbehind stops `--not-pre` matching `--pre`.
LONG_FLAGS: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(r"(?<![\w-])--pre(?:=|\s|$)"),
        "rg --pre runs an arbitrary preprocessor command",
    ),
    (
        re.compile(r"(?<![\w-])--hostname-bin(?:=|\s|$)"),
        "rg --hostname-bin runs an arbitrary command",
    ),
    (
        re.compile(r"(?<![\w-])--exec(?:-batch)?(?:=|\s|$)"),
        "fd --exec runs a command per match",
    ),
]

# Compound-command separators. Deliberately coarse: a segment only needs to be good enough
# to identify its leading command, and over-splitting cannot create a false negative.
SEPARATORS = re.compile(r"&&|\|\||[;|\n]")

ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")


def leading_command(segment: str) -> str:
    """The command a segment runs, with wrappers and env assignments stripped."""
    tokens = segment.split()
    while tokens:
        head = tokens[0]
        if ASSIGNMENT.match(head) or head in WRAPPERS:
            tokens = tokens[1:]
        elif head in WRAPPERS_WITH_ARG:
            tokens = tokens[2:]
        else:
            break
    if not tokens:
        return ""
    return tokens[0].rsplit("/", 1)[-1]


def short_exec_cluster(segment: str) -> bool:
    """True if a short-option cluster carries fd's -x or -X (so `-tf -x` and `-xtf` both hit)."""
    for token in segment.split():
        if re.fullmatch(r"-[A-Za-z]+", token) and ({"x", "X"} & set(token[1:])):
            return True
    return False


def violation(command: str) -> str | None:
    """The reason this command must be denied, or None to stay silent."""
    for segment in SEPARATORS.split(command):
        segment = segment.strip()
        if not segment:
            continue
        tool = leading_command(segment)
        if tool not in {"rg", "fd", "rgd", "fdfind"}:
            continue
        for pattern, reason in LONG_FLAGS:
            if pattern.search(segment):
                return reason
        if tool in {"fd", "fdfind"} and short_exec_cluster(segment):
            return "fd -x / -X runs a command per match"
    return None


def main() -> int:
    payload = json.load(sys.stdin)
    command = (payload.get("tool_input") or {}).get("command")
    if not isinstance(command, str):
        return 0

    reason = violation(command)
    if reason is None:
        return 0

    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": (
                    f"{reason}, which escapes the Bash(rg *) / Bash(fd *) allow rules. "
                    f"Run the search without that flag, or pipe results into the command instead."
                ),
            }
        },
        sys.stdout,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
