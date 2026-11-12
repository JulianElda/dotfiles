import type { Register, RenderChildren } from 'claude-code'

import { split } from './parse'
import { tokenize } from './shell-highlight'
import type { TokenKind } from './shell-highlight'

// Panel frames, from ayu-mirage: green for insights, purple for code blocks.
// (shell-list's command boxes are blue, #a2deff.)
const GREEN = '#87d96c' // vcs.added, the theme's success colour
const PURPLE = '#dfbfff' // syntax.constant

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
    const panel = (children: RenderChildren, color = GREEN) => (
      <Box
        flexDirection="column"
        borderStyle="round"
        borderColor={color}
        borderDimColor
        paddingX={1}
        marginLeft={2}
      >
        {children}
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
          panel(
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
            PURPLE,
          ),
        )
      } else if (s.kind === 'code') {
        // Any other language: Claude Code's own highlighter; unlabelled, plain.
        children.push(panel(<Code source={s.text} language={s.lang || undefined} />, PURPLE))
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
