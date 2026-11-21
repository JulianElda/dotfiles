import { expect, test } from 'claude-code/testing'

const REPLY = [
  'Done, the mod is written.',
  '',
  '`★ Insight ─────────────────────────────────────`',
  '- first point',
  '- second point',
  '`─────────────────────────────────────────────────`',
].join('\n')

const message = (text: string) => ({
  plugin: 'insight-panel',
  component: 'AssistantMessage',
  requestId: 'msg-1',
  props: { text, isFirstOfReply: true },
}) as const

test('an insight is drawn in a bordered panel, the rest by the engine', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    const props = e.props as { text: string }

    return <Text>engine: {props.text}</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...message(REPLY), surface })

    expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe(
      'engine: Done, the mod is written.',
    )
    expect(await ui.find({ type: 'Text', text: /★ Insight/ })).toBeDefined()
    expect((await ui.find({ type: 'Markdown', text: /first point/ }))?.text).toBe(
      '- first point\n- second point',
    )
    await ui.unmount()
  }
})

test('a reply with no insight is left to the engine', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...message('plain reply'), surface: 'terminal' })

  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  expect(await ui.find({ type: 'Text', text: /Insight/ })).toBeUndefined()
  await ui.unmount()
})

test('a shell code block is drawn in a panel with zsh colours', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const reply = ['Run this:', '', '```', '! jq ".a" x.json > y && echo done', '```', '', 'Then commit.'].join('\n')
  const ui = await $.ui.mount({ ...message(reply), surface: 'terminal' })

  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  expect(await ui.find({ type: 'Text', text: /^! $/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^jq$/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^"\.a"$/ })).toBeDefined()
  expect((await ui.find({ type: 'Markdown', text: /commit/ }))?.text).toBe('Then commit.')
  await ui.unmount()
})

test('another language goes to the Code element, a plain block stays plain', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const reply = ['```json', '{ "a": 1 }', '```', '', '```', 'a/', '└── b', '```'].join('\n')
  const ui = await $.ui.mount({ ...message(reply), surface: 'terminal' })
  const codes = await ui.findAll({ type: 'Code' })

  expect(codes.map(c => c.text)).toEqual(['{ "a": 1 }', 'a/\n└── b'])
  await ui.unmount()
})

test('a code block has round-cornered rules above and below and no box, so a copy takes no │', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const reply = ['```bash', 'echo one', 'echo two', '```', '', '```json', '{ "a": 1 }', '```'].join('\n')
  const ui = await $.ui.mount({ ...message(reply), surface: 'terminal' })
  const boxes = await ui.findAll({ type: 'Box' })

  expect(boxes.filter(b => b.props.borderStyle !== undefined)).toHaveLength(0)
  expect(await ui.findAll({ type: 'Text', text: /^─+$/ })).toHaveLength(4)
  const corners = await ui.findAll({ type: 'Text', text: /^[╭╮╰╯]$/ })
  expect(corners.map(c => c.text).join('')).toBe('╭╮╰╯╭╮╰╯')
  await ui.unmount()
})
