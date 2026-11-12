import type { ToolGroupCall } from 'claude-code'
import { expect, test } from 'claude-code/testing'

const call = (id: string, command: string, stdout: string): ToolGroupCall => ({
  tool_use_id: id,
  tool: 'Bash',
  input: { command, description: 'x' },
  isRunning: false,
  isErrored: false,
  isInterrupted: false,
  output: { stdout, stderr: '', interrupted: false },
})

const group = (calls: ToolGroupCall[], extra: Record<string, unknown> = {}) =>
  ({
    plugin: 'shell-list',
    component: 'ToolGroup',
    requestId: 'group-1',
    props: { calls, isActive: false, isExpanded: false, isCallsOnly: true, ...extra },
  }) as const

test('lists the commands and opens one to show its output', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      ...group([
        call('t1', 'uname -sr', 'Linux 6.18\n'),
        call('t2', 'date', '\x1b[1mThu Nov 12\x1b[0m\n'),
      ]),
      surface,
    })

    // Two lines a call: the description, then the command.
    expect(await ui.findAll({ type: 'Button' })).toHaveLength(4)
    expect(await ui.find({ type: 'Text', text: /Linux/ })).toBeUndefined()

    await ui.press({ key: 't2' })
    expect((await ui.find({ type: 'Text', text: /Thu/ }))?.text).toBe('Thu Nov 12')

    await ui.press({ key: 't2' })
    expect(await ui.find({ type: 'Text', text: /Thu/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('leaves expanded groups and groups without shell calls to the engine', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const expanded = await $.ui.mount({
    ...group([call('t1', 'ls', 'a\n')], { isExpanded: true }),
    surface: 'terminal',
  })
  expect((await expanded.find({ type: 'Text' }))?.text).toBe('engine')
  await expanded.unmount()

  const reads = await $.ui.mount({
    ...group([{ ...call('t1', '', ''), tool: 'Read', input: { file_path: '/x' } }]),
    surface: 'terminal',
  })
  expect((await reads.find({ type: 'Text' }))?.text).toBe('engine')
  await reads.unmount()
})

test('a running command shimmers and cannot be opened yet', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const running = { ...call('t1', 'sleep 5', ''), isRunning: true, output: undefined }
  const ui = await $.ui.mount({ ...group([running]), surface: 'terminal' })

  expect(await ui.find({ type: 'Text', text: /^⠋ $/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /▸/ })).toBeUndefined()
  await ui.press({ key: 't1' })
  expect(await ui.find({ type: 'Text', text: /no output/ })).toBeUndefined()
  await ui.unmount()
})

test('a command the model is still writing already shimmers, never an empty box', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const writing = { ...call('t1', '', ''), input: {}, output: undefined }
  const ui = await $.ui.mount({ ...group([writing]), surface: 'terminal' })

  expect(await ui.find({ type: 'Text', text: /^⠋ $/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /^…$/ })).toBeDefined()
  await ui.unmount()
})

test('two lines: the description, then the command; either one opens the output', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const described = { ...call('t1', 'uname -sr', 'Linux 6.18\n'), input: { command: 'uname -sr', description: 'Show the kernel' } }
    const ui = await $.ui.mount({ ...group([described]), surface })

    expect(await ui.find({ type: 'Text', text: 'Show the kernel' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: 'uname' })).toBeDefined()

    await ui.press({ key: 't1:command' })
    expect((await ui.find({ type: 'Text', text: /Linux/ }))?.text).toBe('Linux 6.18')
    await ui.press({ key: 't1' })
    expect(await ui.find({ type: 'Text', text: /Linux/ })).toBeUndefined()
    await ui.unmount()
  }
})

test('a finished command without a description keeps the one line', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const bare = { ...call('t1', 'ls', 'a\n'), input: { command: 'ls' } }
  const ui = await $.ui.mount({ ...group([bare]), surface: 'terminal' })

  expect(await ui.findAll({ type: 'Button' })).toHaveLength(1)
  expect(await ui.find({ type: 'Text', text: '$ ' })).toBeDefined()
  await ui.unmount()
})

test('a non-shell row in the group is a Button too, and opens its own output', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  for (const surface of ['terminal', 'desktop'] as const) {
    const skill: ToolGroupCall = {
      ...call('s1', '', ''),
      tool: 'Skill',
      input: { skill: 'plugin-authoring' },
      output: { success: true, commandName: 'plugin-authoring' },
    }
    const ui = await $.ui.mount({ ...group([call('t1', 'ls', 'a\n'), skill]), surface })

    expect(await ui.find({ type: 'Text', text: ' plugin-authoring' })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /commandName/ })).toBeUndefined()

    await ui.press({ key: 's1' })
    expect(await ui.find({ type: 'Text', text: /"commandName": "plugin-authoring"/ })).toBeDefined()
    // The flag outlives the mount: close it for the next surface.
    await ui.press({ key: 's1' })
    await ui.unmount()
  }
})

test('a failed call no longer hands the group back: it is drawn with a ✗ and its error', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const failed: ToolGroupCall = {
    ...call('t2', 'ls /nope', ''),
    isErrored: true,
    output: "ls: cannot access '/nope': No such file or directory",
  }
  const ui = await $.ui.mount({
    ...group([call('t1', 'ls', 'a\n'), failed], { isCallsOnly: false }),
    surface: 'terminal',
  })

  expect(await ui.find({ type: 'Text', text: 'engine' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: ' ✗' })).toBeDefined()
  await ui.press({ key: 't2' })
  expect(await ui.find({ type: 'Text', text: /cannot access/ })).toBeDefined()
  await ui.press({ key: 't2' })
  await ui.unmount()

  // Not calls only, and nothing failed: some other row is in it. Engine's line.
  const other = await $.ui.mount({
    ...group([call('t1', 'ls', 'a\n')], { isCallsOnly: false }),
    surface: 'terminal',
  })
  expect((await other.find({ type: 'Text' }))?.text).toBe('engine')
  await other.unmount()
})
