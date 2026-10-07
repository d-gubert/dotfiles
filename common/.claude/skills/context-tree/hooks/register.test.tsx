import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'context-tree',
  component: 'Pane',
  requestId: 'context-tree',
  props: { title: 'Context', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} },
} as const

test('a Bash call shows as a node with command and output children', async ($, on) => {
  mock.env(on, { TMPDIR: '/tmp/context-tree-test/' })
  on('session.id', () => ({ value: 'test-session' }))
  on('fs.write', () => ({ value: undefined }))
  on('tool.call', () => ({ result: { stdout: 'hi', stderr: '', interrupted: false }, text: 'hi' }))
  await $.tool.call({ tool: 'Bash', command: 'echo hi' })

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ text: /Session start/ })).toBeDefined()
    const row = await ui.find({ type: 'Button', text: /\$ echo hi/ })
    expect(row).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /output/ })).toBeUndefined()
    await ui.press({ key: row!.key! })
    expect(await ui.find({ type: 'Button', text: /output/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', text: /command/ })).toBeDefined()
    await ui.press({ key: row!.key! })
    await ui.unmount()
  }
})

const HEAD = [
  { type: 'user', message: { role: 'user', content: 'hello' } },
  { type: 'attachment', attachment: { type: 'skill_listing', content: '- a skill' }, rendered: [{ content: '<system-reminder>- a skill</system-reminder>' }] },
  { type: 'attachment', attachment: { type: 'total_tokens_reminder' }, rendered: [{ content: '<total_tokens>1000 tokens left</total_tokens>' }] },
  { type: 'attachment', attachment: { type: 'instructions', files: [{ path: '/home/me/CLAUDE.md', type: 'User', content: '# Style' }] } },
  { type: 'attachment', attachment: { type: 'session_context', context: { userEmail: 'me@example.com', gitStatus: 'clean' } } },
  { type: 'attachment', attachment: { type: 'prompt_snapshot', cliPrefix: 'You are Claude Code.', systemPrompt: ['# Harness\nrules', '# Memory\nnotes'] } },
  { type: 'attachment', attachment: { type: 'command_permissions', allowedTools: [] }, rendered: [{ content: 'turn one' }] },
  { type: 'attachment', attachment: { type: 'prompt_snapshot', systemPrompt: [], tools: [{ name: 'Bash' }, { name: 'Read' }] } },
]
  .map(row => JSON.stringify(row))
  .join('\n')

test('the session start node lists what the transcript head holds', async ($, on) => {
  mock.env(on, { TMPDIR: '/tmp/context-tree-test/', HOME: '/home/me' })
  on('session.id', () => ({ value: 'test-session' }))
  on('session.cwd', () => ({ value: '/home/me/project' }))
  on('fs.write', () => ({ value: undefined }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: HEAD, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false }, text: '' }))
  await $.tool.call({ tool: 'Bash', command: 'true' })

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'expand' })
  for (const label of ['/home/me/CLAUDE.md', 'userEmail', 'gitStatus', 'You are Claude Code.', 'Harness', 'Memory', 'Bash', 'Read', 'skill_listing']) {
    expect(await ui.find({ type: 'Button', text: new RegExp(label) })).toBeDefined()
  }
  expect(await ui.find({ type: 'Button', text: /command_permissions/ })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /total_tokens_reminder/ })).toBeUndefined()
  await ui.unmount()
})
