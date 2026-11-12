import { expect, test } from "claude-code/testing";

import { shimmer } from "../hooks/format";
import { tokenize } from "../hooks/highlight";

const kinds = (line: string) =>
  tokenize(line)
    .filter((t) => t.text.trim() !== "" && t.kind !== "plain")
    .map((t) => `${t.kind}:${t.text}`);

test("commands after separators, strings with variables, redirections", () => {
  expect(kinds(`FOO=1 git -C ~/x log | rg "feat $USER" && echo $HOME > /tmp/o 2>&1`)).toEqual([
    "command:git",
    "path:~/x",
    "command:rg",
    'string:"feat ',
    "quotedVariable:$USER",
    'string:"',
    "command:echo",
    "redirection:>",
    "path:/tmp/o",
    "redirection:2>&1",
  ]);
});

test("precommands, reserved words, substitutions and globs", () => {
  expect(kinds(`sudo -E ls *.ts; if true; then echo $(date +%H); fi`)).toEqual([
    "precommand:sudo",
    "command:ls",
    "glob:*",
    "reserved:if",
    "command:true",
    "reserved:then",
    "command:echo",
    "substitution:$(",
    "command:date",
    "substitution:)",
    "reserved:fi",
  ]);
});

test("a cut quote runs to the end; # is a plain word, not a comment", () => {
  expect(kinds(`echo 'unclosed…`)).toEqual(["command:echo", "string:'unclosed…"]);
  expect(kinds("head -1 # comment")).toEqual(["command:head"]);
});

test("only the * of a glob is coloured, and a glob is no path", () => {
  expect(tokenize("ls ~/.config/*.toml").map((t) => `${t.kind}:${t.text}`)).toEqual([
    "command:ls",
    "plain: ",
    "plain:~/.config/",
    "glob:*",
    "plain:.toml",
  ]);
});

test("the shimmer band sweeps across and starts over", () => {
  const lit = (frame: number) =>
    shimmer("abcdefgh", frame)
      .filter((p) => p.isLit)
      .map((p) => p.text)
      .join("");

  expect(lit(0)).toBe("");
  expect(lit(2)).toBe("abcd");
  expect(lit(4)).toBe("efgh");
  expect(lit(8)).toBe("");
  expect(lit(10)).toBe("abcd");
});
