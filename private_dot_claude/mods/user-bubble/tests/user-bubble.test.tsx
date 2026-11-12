import { expect, test } from 'claude-code/testing'

type Drawn = { props?: Record<string, unknown> }
type Finder = { findAll(q: { type: 'Box' }): Promise<unknown[]> }

/** The bubble's width: the column Box that stacks its edges and body. */
async function bubbleWidth(ui: Finder) {
  const boxes = (await ui.findAll({ type: 'Box' })) as Drawn[]

  return boxes.find(b => b.props?.flexDirection === 'column')?.props?.width
}

const message = (text: string, kind: string) =>
  ({
    plugin: 'user-bubble',
    component: 'UserMessage',
    requestId: 'm1',
    props: { text, origin: { kind }, isExpanded: false },
    viewport: { columns: 100, rows: 40 },
  }) as never

test('a typed message is a filled panel as wide as the conversation', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...message('hello there\nhi\n', 'composer'), surface })

    expect(await ui.find({ type: 'Text', text: 'engine' })).toBeUndefined()
    expect(await ui.find({ type: 'Text', text: 'hello there\nhi' })).toBeDefined()
    // The lip spans the panel: corners plus width - 2 half blocks.
    expect(await ui.find({ type: 'Text', text: `▗${'▄'.repeat(97)}▖` })).toBeDefined()
    expect(await bubbleWidth(ui)).toBe(99)
    await ui.unmount()
  }
})

test('a long message wraps inside the same width', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...message('x'.repeat(300), 'composer'), surface: 'terminal' })
  expect(await bubbleWidth(ui)).toBe(99)
  await ui.unmount()
})

test('a message the person did not type keeps the engine row', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...message('task done', 'task-notification'), surface: 'terminal' })
  expect((await ui.find({ type: 'Text' }))?.text).toBe('engine')
  await ui.unmount()
})
