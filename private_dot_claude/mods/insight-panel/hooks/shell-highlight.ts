// A copy of shell-list/hooks/highlight.ts: a mod imports only its own files.

// The token kinds zsh-syntax-highlighting's main highlighter tells apart, as
// far as one line of text shows them (it also checks commands and paths on
// disk, which a mod drawing a past command cannot).
export type TokenKind =
  | "command" // arg0: a command, builtin, function or alias
  | "precommand" // sudo, env, nohup, ...
  | "reserved" // if, then, for, do, done, ...
  | "string" // '...', "...", $'...'
  | "quotedVariable" // $VAR inside "..."
  | "redirection" // > >> < 2> 2>&1 &>
  | "substitution" // the $( and ) of a command substitution
  | "glob" // the * and ? of a word; the rest of it stays plain
  | "path" // a word that looks like a path
  | "plain"; // options, assignments, separators, plain words

export type Token = { kind: TokenKind; text: string };

// From main-highlighter.zsh (0.8.0) precommand_options.
const PRECOMMANDS = new Set([
  "-",
  "builtin",
  "command",
  "exec",
  "noglob",
  "doas",
  "nice",
  "pkexec",
  "sudo",
  "stdbuf",
  "eatmydata",
  "catchsegv",
  "nohup",
  "setsid",
  "env",
  "ionice",
  "strace",
  "proxychains",
  "torsocks",
  "torify",
]);
const RESERVED = new Set([
  "if",
  "then",
  "else",
  "elif",
  "fi",
  "case",
  "esac",
  "for",
  "select",
  "while",
  "until",
  "do",
  "done",
  "in",
  "function",
  "time",
  "nocorrect",
  "foreach",
  "end",
  "repeat",
  "coproc",
  "!",
  "{",
  "}",
  "[[",
  "]]",
]);
// Longest first, so `2>&1` wins over `2>` and `&&` over `&`.
const REDIRECTIONS = ["2>&1", "&>>", "&>", "2>>", "2>", ">>", ">|", ">&", "<<<", "<<", ">", "<"];
const SEPARATORS = ["&&", "||", "|&", "|", ";", "&", "(", ")"];
const WORD_END = /[\s'"|;&<>()]/;
const ASSIGNMENT = /^[A-Za-z_][A-Za-z0-9_]*=/;
const VARIABLE = /^\$(\{[^}]*\}?|[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-])/;
const PATHLIKE = /^(~|\.{1,2})?\//;

/**
 * Splits one line of shell into tokens coloured the way zsh-syntax-highlighting
 * colours them: a small tokenizer, not a parser. An unclosed quote runs to the
 * end, since the line may be cut short. `#` starts no comment: the shell runs
 * without interactive_comments, so it is an ordinary word there too.
 */
export function tokenize(line: string): Token[] {
  const tokens: Token[] = [];
  const substitutions: number[] = []; // paren depth at each open $(
  let depth = 0;
  let expectCommand = true;
  let afterPrecommand = false; // its own options (sudo -E) are no command
  let i = 0;

  const push = (kind: TokenKind, text: string) => tokens.push({ kind, text });

  while (i < line.length) {
    const rest = line.slice(i);
    const ch = line[i] as string;

    if (/\s/.test(ch)) {
      const ws = /^\s+/.exec(rest)![0];
      push("plain", ws);
      i += ws.length;
      continue;
    }

    if (ch === "'" || rest.startsWith("$'")) {
      const open = ch === "'" ? 1 : 2;
      const close = line.indexOf("'", i + open);
      const text = line.slice(i, close === -1 ? line.length : close + 1);
      push("string", text);
      i += text.length;
      expectCommand = false;
      continue;
    }

    if (ch === '"') {
      // "..." is yellow, the $VARs inside it cyan.
      let j = i + 1;
      let run = '"';
      while (j < line.length && line[j] !== '"') {
        const v = line[j] === "$" ? VARIABLE.exec(line.slice(j)) : null;
        if (v) {
          push("string", run);
          push("quotedVariable", v[0]);
          run = "";
          j += v[0].length;
        } else {
          const step = line[j] === "\\" ? 2 : 1;
          run += line.slice(j, j + step);
          j += step;
        }
      }
      if (j < line.length) run += '"';
      push("string", run);
      i = Math.min(j + 1, line.length);
      expectCommand = false;
      continue;
    }

    if (rest.startsWith("$(")) {
      push("substitution", "$(");
      depth += 1;
      substitutions.push(depth);
      i += 2;
      expectCommand = true;
      continue;
    }

    const redirection = REDIRECTIONS.find((r) => rest.startsWith(r));
    if (redirection) {
      push("redirection", redirection);
      i += redirection.length;
      continue;
    }

    const separator = SEPARATORS.find((s) => rest.startsWith(s));
    if (separator) {
      if (separator === "(") depth += 1;
      if (separator === ")") {
        if (substitutions[substitutions.length - 1] === depth) {
          substitutions.pop();
          depth -= 1;
          push("substitution", ")");
          i += 1;
          expectCommand = false;
          continue;
        }
        depth -= 1;
      }
      push("plain", separator);
      i += separator.length;
      expectCommand = separator !== ")";
      continue;
    }

    let j = i;
    while (j < line.length && !WORD_END.test(line[j] as string)) j++;
    if (j === i) j = i + 1;
    const word = line.slice(i, j);
    i = j;

    if (expectCommand && afterPrecommand && word.startsWith("-")) {
      push("plain", word);
      continue;
    }
    afterPrecommand = expectCommand && PRECOMMANDS.has(word);

    if (expectCommand && ASSIGNMENT.test(word)) {
      push("plain", word);
    } else if (expectCommand && RESERVED.has(word)) {
      push("reserved", word);
    } else if (expectCommand && PRECOMMANDS.has(word)) {
      push("precommand", word); // the word after it is still a command
    } else if (expectCommand) {
      push("command", word);
      expectCommand = false;
    } else if (/[*?]/.test(word)) {
      for (const part of word.split(/([*?]+)/)) {
        if (part !== "") push(/^[*?]+$/.test(part) ? "glob" : "plain", part);
      }
    } else if (PATHLIKE.test(word)) {
      push("path", word);
    } else {
      push("plain", word);
    }
  }

  return tokens;
}
