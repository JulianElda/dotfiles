export type Segment =
  | { kind: "text" | "insight"; text: string }
  | { kind: "code"; text: string; lang: string };

// `★ Insight ─────────` opens a block, a line of box-drawing dashes closes it.
// Backticks are optional so a block written without them still matches.
const OPEN = /^\s*`?\s*★\s*Insight\b[^\n]*$/;
const CLOSE = /^\s*`?\s*─{8,}\s*`?\s*$/;
// A fenced code block: ``` or ~~~ (three or more), an optional language.
const FENCE = /^\s*(`{3,}|~{3,})\s*([\w+#.-]*)[^`]*$/;

/**
 * Splits an assistant message into plain markdown, insight bodies and fenced
 * code blocks, in order. A block still open at the end (the reply is
 * streaming) counts as one, so its panel grows as the text arrives. A fence
 * inside an insight belongs to the insight's markdown.
 */
export function split(text: string): Segment[] {
  const segments: Segment[] = [];
  let kind: Segment["kind"] = "text";
  let fence = "";
  let lang = "";
  let lines: string[] = [];

  const flush = () => {
    if (kind === "code") {
      // Keep the code's indentation; drop only blank lines around it.
      while (lines.length > 0 && lines[0]!.trim() === "") lines.shift();
      while (lines.length > 0 && lines[lines.length - 1]!.trim() === "") lines.pop();
      if (lines.length > 0) segments.push({ kind, text: lines.join("\n"), lang });
    } else {
      const body = lines.join("\n").trim();
      if (body !== "") segments.push({ kind, text: body });
    }
    lines = [];
  };

  for (const line of text.split("\n")) {
    const f = FENCE.exec(line);

    if (kind === "text" && OPEN.test(line)) {
      flush();
      kind = "insight";
    } else if (kind === "insight" && CLOSE.test(line)) {
      flush();
      kind = "text";
    } else if (kind === "text" && f) {
      flush();
      kind = "code";
      fence = f[1]!;
      lang = f[2]!.toLowerCase();
    } else if (kind === "code" && f && f[1]!.startsWith(fence) && f[2] === "") {
      flush();
      kind = "text";
    } else {
      lines.push(line);
    }
  }
  flush();

  return segments;
}
