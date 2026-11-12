// ANSI escape sequences, then every control character but tab and newline:
// a Text refuses them, and a command's colours mean nothing here.
const ANSI = /\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[@-_]/g;
const CONTROL = /[\x00-\x08\x0b-\x1f\x7f]/g;

export function clean(text: string): string {
  return text.replace(ANSI, "").replace(/\r\n?/g, "\n").replace(CONTROL, "");
}

/** One line for the row: the command's first line, cut to `width` columns. */
export function oneLine(text: string, width: number): string {
  const lines = clean(text).trim().split("\n");
  let line = lines[0] ?? "";
  const isCut = lines.length > 1 || line.length > width;

  if (line.length > width) line = line.slice(0, Math.max(1, width - 1));

  return isCut ? `${line}…` : line;
}

/** The output's text: a shell's stdout and stderr, a plain string, else its JSON. */
function outputText(output: unknown): string[] {
  if (typeof output === "string") return [output];
  if (output === undefined || output === null) return [];

  const o = output as { stdout?: unknown; stderr?: unknown };
  if (typeof o.stdout === "string" || typeof o.stderr === "string") {
    return [o.stdout, o.stderr].filter((p): p is string => typeof p === "string");
  }

  return [JSON.stringify(output, null, 2)];
}

/** The output to show under an opened row, at most `max` lines. */
export function outputLines(output: unknown, max: number): { lines: string[]; hidden: number } {
  const parts = outputText(output)
    .map((p) => clean(p).replace(/\n+$/, ""))
    .filter((p) => p !== "");
  const all = parts.length === 0 ? ["(no output)"] : parts.join("\n").split("\n");

  return { lines: all.slice(0, max), hidden: Math.max(0, all.length - max) };
}

/** What a non-shell call in the group is about: its path, pattern or URL. */
export function subject(input: unknown): string {
  const i = (input ?? {}) as Record<string, unknown>;

  for (const field of ["file_path", "pattern", "path", "url", "query", "skill", "description"]) {
    const v = i[field];
    if (typeof v === "string" && v !== "") return v;
  }

  return "";
}

/**
 * Splits `text` into the parts a shimmer draws: a band of `band` characters,
 * lit, that sweeps left to right `step` characters a frame and starts over.
 */
export function shimmer(
  text: string,
  frame: number,
  band = 4,
  step = 2,
): Array<{ text: string; isLit: boolean }> {
  const period = text.length + band * 2;
  const start = ((frame * step) % period) - band;
  const from = Math.max(0, start);
  const to = Math.max(0, Math.min(text.length, start + band));

  return [
    { text: text.slice(0, from), isLit: false },
    { text: text.slice(from, to), isLit: true },
    { text: text.slice(to), isLit: false },
  ].filter((p) => p.text !== "");
}
