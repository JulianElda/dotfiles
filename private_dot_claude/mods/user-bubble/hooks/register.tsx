import type { Register } from 'claude-code'

// The terminal's background is #1f2430 (ayu-mirage) and the engine's own band
// behind a prompt #282e3b; the bubble is a bluer step up from both.
const BUBBLE_BG = '#2a3a52'

// Padding 2 a side.
const PAD = 2

export const register: Register = on => {
  on('ui.render', { component: 'UserMessage' }, ($, e, next) => {
    const { text, origin } = e.props

    // Only what the person typed: notifications, task results and other
    // agents' messages keep the engine's row.
    if (origin.kind !== 'composer') return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const columns = e.viewport?.columns ?? 100
    const body = text.replace(/\s+$/, '')
    // The conversation's width, whatever the message holds; the last column
    // left free, so the panel never wraps at the edge.
    const width = Math.max(20, columns - 1)
    const span = Math.max(0, width - 2)

    // No border line: a terminal paints a background on whole cells and a
    // border glyph sits mid-cell, so a fill never meets the line (a dark ring
    // stays between them). The edges are half blocks in the fill's colour
    // instead: a half-row lip above and below, a quarter block at each corner,
    // which reads as a rounded, filled panel.
    return (
      <Box flexDirection="column" width={width}>
        <Text color={BUBBLE_BG}>{`▗${'▄'.repeat(span)}▖`}</Text>
        <Box backgroundColor={BUBBLE_BG} paddingX={PAD}>
          <Text weight="bold">{body}</Text>
        </Box>
        <Text color={BUBBLE_BG}>{`▝${'▀'.repeat(span)}▘`}</Text>
      </Box>
    )
  })
}
