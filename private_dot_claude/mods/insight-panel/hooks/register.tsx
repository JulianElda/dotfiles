import type { Register, RenderChildren } from 'claude-code'

import { split } from './parse'
import { tokenize } from './shell-highlight'
import type { TokenKind } from './shell-highlight'

// From ayu-mirage: a green frame for insights, purple rules for code blocks.
// (shell-list's command boxes are blue, #a2deff.)
const GREEN = '#87d96c' // vcs.added, the theme's success colour
const PURPLE = '#dfbfff' // syntax.constant
// PURPLE half-blended into the theme's background (#1f2430), standing in for
// borderDimColor on the code rules, which are Text, not a border.
const PURPLE_DIM = '#7f7197'
// Longer than any terminal is wide; a one-row clipping Box cuts it to fit
// (`wrap="truncate"` would end it in `…`).
const RULE = '─'.repeat(512)

// zsh-syntax-highlighting's default styles in the terminal's own palette, as
// in shell-list: a shell block reads like the prompt it gets pasted into.
const TERM = {
  green: '#a6cc70',
  yellow: '#fad07b',
  cyan: '#90e1c6',
  magenta: '#cfbafa',
  blue: '#6dcbfa',
}
type Style = { color?: string; underline?: boolean }
const STYLE: Record<TokenKind, Style> = {
  command: { color: TERM.green },
  precommand: { color: TERM.green, underline: true },
  reserved: { color: TERM.yellow },
  string: { color: TERM.yellow },
  quotedVariable: { color: TERM.cyan },
  redirection: { color: TERM.yellow },
  substitution: { color: TERM.magenta },
  glob: { color: TERM.blue },
  path: { underline: true },
  plain: {},
}

const SHELLS = new Set(['sh', 'bash', 'zsh', 'shell', 'console', 'shellsession'])
// A prompt mark before the command: Claude Code's `! ` or a shell's `$ `.
const PROMPT = /^(\s*)([!$]) /

/**
 * Whether a code block is shell: its fence says so, or, unlabelled, its first
 * line starts with a prompt mark. Other unlabelled blocks (trees, mockups)
 * stay plain.
 */
function isShell(lang: string, text: string): boolean {
  return SHELLS.has(lang) || (lang === '' && PROMPT.test(text))
}

export const register: Register = on => {
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (e.props.isSummary) return next(e)

    const segments = split(e.props.text)
    if (segments.every(s => s.kind === 'text')) return next(e)

    const { Box, Text, Markdown, Code } = $.ui.resolve(e)
    const panel = (children: RenderChildren) => (
      <Box
        flexDirection="column"
        borderStyle="round"
        borderColor={GREEN}
        borderDimColor
        paddingX={1}
        marginLeft={2}
      >
        {children}
      </Box>
    )
    // Code blocks get a rule above and below instead of a box: a box's side
    // `│`s sit on every line, so a multi-line selection copies them with the
    // code. The rules carry the round corners, one column left of the code,
    // so the code keeps the 2-column indent of the reply text.
    const rule = (left: string, right: string) => (
      <Box flexDirection="row">
        <Box flexShrink={0}>
          <Text color={PURPLE_DIM}>{left}</Text>
        </Box>
        {/* Shrinks to the room between the corners; one row, the rest clipped. */}
        <Box flexGrow={1} flexShrink={1} height={1} overflow="hidden">
          <Text color={PURPLE_DIM}>{RULE}</Text>
        </Box>
        <Box flexShrink={0}>
          <Text color={PURPLE_DIM}>{right}</Text>
        </Box>
      </Box>
    )
    const codePanel = (children: RenderChildren) => (
      <Box flexDirection="column" marginLeft={1}>
        {rule('╭', '╮')}
        <Box flexDirection="column" marginLeft={1}>
          {children}
        </Box>
        {rule('╰', '╯')}
      </Box>
    )
    const children = []
    // One blank line between text and a panel; none between two panels in a
    // row, which sit flush like shell-list's command boxes.
    const gapBefore = (i: number) => {
      const prev = segments[i - 1]
      if (!prev) return 0
      return prev.kind !== 'text' && segments[i]!.kind !== 'text' ? 0 : 1
    }

    for (const [i, s] of segments.entries()) {
      if (s.kind === 'insight') {
        children.push(
          panel([
            <Text bold color={GREEN}>
              ★ Insight
            </Text>,
            // Dimmed: the body reads greyer than the reply around it.
            <Markdown text={s.text} dimColor />,
          ]),
        )
      } else if (s.kind === 'code' && isShell(s.lang, s.text)) {
        children.push(
          codePanel(
            s.text.split('\n').map(line => {
              const prompt = PROMPT.exec(line)
              const rest = prompt ? line.slice(prompt[0].length) : line

              return (
                <Text>
                  {prompt && <Text color={PURPLE}>{prompt[0]}</Text>}
                  {tokenize(rest).map(t => (
                    <Text {...STYLE[t.kind]}>{t.text}</Text>
                  ))}
                </Text>
              )
            }),
          ),
        )
      } else if (s.kind === 'code') {
        // Any other language: Claude Code's own highlighter; unlabelled, plain.
        children.push(codePanel(<Code source={s.text} language={s.lang || undefined} />))
      } else if (i === 0) {
        // The engine draws the leading text, so the reply keeps its bullet.
        children.push(await next({ ...e, props: { ...e.props, text: s.text } }))
      } else {
        children.push(
          <Box paddingLeft={2}>
            <Markdown text={s.text} />
          </Box>,
        )
      }
    }

    return (
      <Box flexDirection="column">
        {children.map((child, i) => (
          <Box flexDirection="column" marginTop={gapBefore(i)}>
            {child}
          </Box>
        ))}
      </Box>
    )
  })
}
