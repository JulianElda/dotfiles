import { atom, memberOf, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer, ToolGroupCall } from 'claude-code'

import { oneLine, outputLines, shimmer, subject } from './format'
import { tokenize } from './highlight'
import type { TokenKind } from './highlight'

const MAX_OUTPUT_LINES = 30

// zsh-syntax-highlighting 0.8.0's default styles (~/.zshrc sets none), in the
// terminal's own palette as measured from a screenshot of its prompt. ANSI
// names ('green') don't work: Claude Code draws them in its own shades.
const TERM = {
  green: '#a6cc70',
  yellow: '#fad07b',
  cyan: '#90e1c6',
  magenta: '#cfbafa',
  blue: '#6dcbfa',
}
type Style = { color?: string; bold?: boolean; underline?: boolean }
const STYLE: Record<TokenKind, Style> = {
  command: { color: TERM.green }, // arg0, alias, builtin, function, command
  precommand: { color: TERM.green, underline: true },
  reserved: { color: TERM.yellow },
  string: { color: TERM.yellow }, // single-, double-, dollar-quoted-argument
  quotedVariable: { color: TERM.cyan }, // dollar-double-quoted-argument
  redirection: { color: TERM.yellow },
  substitution: { color: TERM.magenta }, // command-substitution-delimiter
  glob: { color: TERM.blue }, // globbing
  path: { underline: true }, // path (zsh underlines only paths that exist)
  plain: {}, // options, assignments, separators: none
}

// One flag per call, keyed by its tool_use_id: whether its output shows.
const isOpen = atom({ plugin: 'shell-list', key: 'isOpen' } as const, false)

// The shimmer's clock: ticks while any shell command runs. Only rows of a
// group with a running call read it, so a tick redraws just those.
const frame = atom({ plugin: 'shell-list', key: 'frame' } as const, 0)
const FRAME_MS = 100
const SPINNER = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

// How Claude Code draws a running line: dim text, a light band sweeping over it.
const SHIMMER_BASE = 'inactive'
const SHIMMER_LIT = 'text'

// The frame and prompt colour of a finished command: ayu-mirage's blue l4
// (insights are green, code blocks purple).
const BLUE = '#a2deff'

// What dimColor drew before (see the caret).
const MUTED = 'inactive'

/**
 * Whether a call is not done: running, or not started yet (the model is still
 * writing its input, or it waits for a permission). A finished call has an
 * output, an error or an interruption.
 */
const isPending = (call: ToolGroupCall) =>
  call.isRunning || (call.output === undefined && !call.isErrored && !call.isInterrupted)

// Module state on purpose: a reload drops the old timer with the old module.
// The clock ticks while a turn runs (a command's box shimmers from the moment
// the model starts writing it) and while a shell command runs (a background
// one can outlast its turn).
let isTurnActive = false
let running = 0
let ticker: Timer | null = null

function sync($: EngineInterface) {
  const isWanted = isTurnActive || running > 0
  if (isWanted && !ticker) {
    ticker = $.clock.every(FRAME_MS, () => void update($, frame, n => n + 1))
  } else if (!isWanted && ticker) {
    ticker.cancel()
    ticker = null
  }
}

export const register: Register = on => {
  on('turn.start', ($, e, next) => {
    isTurnActive = true
    sync($)

    return next(e)
  })

  on('turn.complete', ($, e, next) => {
    isTurnActive = false
    sync($)

    return next(e)
  })

  on('turn.abort', ($, e, next) => {
    isTurnActive = false
    sync($)

    return next(e)
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    running += 1
    sync($)

    try {
      return await next(e)
    } finally {
      running -= 1
      sync($)
    }
  })

  on('ui.render', { component: 'ToolGroup' }, async ($, e, next) => {
    const { calls, isExpanded, isCallsOnly } = e.props

    // ctrl+o / --verbose already shows every call in full.
    if (isExpanded) return next(e)

    // isCallsOnly turns false for a failed or interrupted call as much as for a
    // row that is no call (a recalled memory, hook timing), and does not say
    // which. With a failed call in the group, draw it anyway: else one failure
    // turns a whole turn's boxes back into "ran N shell commands" (a turn whose
    // text the person does not see is one group). The cost: such a row in that
    // same group is not shown.
    const hasFailed = calls.some(c => c.isErrored || c.isInterrupted)
    if (isCallsOnly !== true && !(isCallsOnly === false && hasFailed)) return next(e)
    if (!calls.some(c => c.tool === 'Bash')) return next(e)

    const { Box, Text, Button } = $.ui.resolve(e)
    const columns = e.viewport?.columns
    // margin 2 + border 2 + padding 2 + the "▸ " or "$ " prefix 2, and 2 spare
    const width = Math.max(20, (columns ?? 100) - 10)
    // Every box as wide as the conversation, whatever it holds: the margin 2,
    // and the last column left free so a box never wraps at the edge.
    const boxWidth = columns === undefined ? undefined : Math.max(24, columns - 3)
    const tick = calls.some(isPending) ? await read($, frame) : 0
    const items = []

    for (const [i, call] of calls.entries()) {
      const id = call.tool_use_id ?? `${e.requestId}:${i}`
      const mark = call.isErrored || call.isInterrupted ? '✗' : null
      const pending = isPending(call)
      const rows = []

      const open = await read($, memberOf(isOpen, { requestId: id }))
      const canOpen = !pending
      const toggle = () => {
        if (canOpen) void update($, memberOf(isOpen, { requestId: id }), v => !v)
      }
      const caret = pending ? (
        <Text color={SHIMMER_LIT}>{SPINNER[tick % SPINNER.length]} </Text>
      ) : (
        // A colour, never dimColor, and no hover: the terminal lifts every dim
        // run of a transcript row under the pointer, and the whole group is one
        // row, so every caret lit together.
        <Text color={MUTED}>{open ? '▾ ' : '▸ '}</Text>
      )
      const failed = mark && <Text color="error"> {mark}</Text>
      // Where the output starts: the Button's leading cell + "▸ " or "$ ".
      let outputIndent = 3

      // Every row is a Button: a click on a bare Text falls through to the
      // engine's own row, which unfolds the whole group in place of the boxes.
      if (call.tool !== 'Bash') {
        const about = oneLine(subject(call.input), width - call.tool.length - 1)

        rows.push(
          <Button key={id} plain onPress={toggle}>
            {caret}
            <Text color={MUTED}>{call.tool}</Text>
            {about !== '' && <Text> {about}</Text>}
            {failed}
          </Button>,
        )
      } else {
        const input = call.input as { command?: string; description?: string } | null
        const command = input?.command ?? ''
        const description = oneLine(input?.description ?? '', width)
        const prompt = <Text color={pending ? SHIMMER_BASE : BLUE}>$ </Text>
        const commandText = pending
          ? shimmer(oneLine(command, width) || '…', tick).map(p => (
              <Text color={p.isLit ? SHIMMER_LIT : SHIMMER_BASE}>{p.text}</Text>
            ))
          : tokenize(oneLine(command, width)).map(t => <Text {...STYLE[t.kind]}>{t.text}</Text>)

        // A Button holds only Text, never a column Box, so the two lines are
        // two Buttons that toggle the same flag. A finished call without a
        // description keeps the one line "▸ $ command".
        if (description === '' && !pending) {
          outputIndent = 5
          rows.push(
            <Button key={id} plain onPress={toggle}>
              {caret}
              {prompt}
              {commandText}
              {failed}
            </Button>,
          )
        } else {
          rows.push(
            <Button key={id} plain onPress={toggle}>
              {caret}
              {pending
                ? shimmer(description || '…', tick).map(p => (
                    <Text color={p.isLit ? SHIMMER_LIT : SHIMMER_BASE}>{p.text}</Text>
                  ))
                : <Text weight="bold" color={MUTED}>{description}</Text>}
              {failed}
            </Button>,
            // The "$ " starts where the caret does: each Button draws the same
            // leading cell, so the prompt sits under the arrow.
            <Button key={`${id}:command`} plain onPress={toggle}>
              {prompt}
              {commandText}
            </Button>,
          )
        }
      }

      if (open && canOpen) {
        const { lines, hidden } = outputLines(call.output, MAX_OUTPUT_LINES)
        rows.push(
          <Box flexDirection="column" paddingLeft={outputIndent}>
            <Text color={call.isErrored ? 'error' : MUTED}>
              {lines.join('\n')}
            </Text>
            {hidden > 0 && (
              <Text color={MUTED} italic>
                … {hidden} more lines (ctrl+o shows all)
              </Text>
            )}
          </Box>,
        )
      }

      // The same frame as the insight panel: round, dimmed, padding 1; blue.
      items.push(
        <Box
          flexDirection="column"
          width={boxWidth}
          borderStyle="round"
          // A running command's frame is grey, as the shimmer's base.
          borderColor={pending ? SHIMMER_BASE : BLUE}
          borderDimColor
          // The Button draws a cell of its own before the arrow, so the left
          // side needs no padding to match the right.
          paddingRight={1}
          marginLeft={2}
        >
          {rows}
        </Box>,
      )
    }

    // The boxes of one group sit flush against each other. No negative margin
    // to eat the transcript's blank line: the row above paints over the border.
    return (
      <Box flexDirection="column">
        {items}
      </Box>
    )
  })
}
