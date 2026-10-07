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
    expect(await ui.find({ text: /on: tool\.call/ })).toBeDefined()
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

/** Answers the reads of the transcript: the head, and the first chunk of the whole file. */
const transcript = (head: string, whole: string) => (_$: unknown, e: { argv: readonly string[] }) => {
  const out = e.argv[1]?.startsWith('{ print }') ? head : e.argv.includes('from=0') ? `${whole}\n` : ''
  return { value: { exitCode: 0, stdout: out, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
}

test('the session start node lists what the transcript head holds', async ($, on) => {
  mock.env(on, { TMPDIR: '/tmp/context-tree-test/', HOME: '/home/me' })
  on('session.id', () => ({ value: 'test-session' }))
  on('session.cwd', () => ({ value: '/home/me/project' }))
  on('fs.write', () => ({ value: undefined }))
  on('process.run', transcript(HEAD, HEAD))
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

const TURNS = [
  { type: 'user', uuid: 'p1', promptId: 'prompt-1', message: { role: 'user', content: 'list the files' } },
  ...HEAD.split('\n').slice(1).map(line => JSON.parse(line)),
  { type: 'assistant', message: { content: [{ type: 'tool_use', id: 'call-1', name: 'Bash', input: { command: 'ls -la', description: 'List files' } }] } },
  { type: 'user', toolUseResult: {}, message: { content: [{ type: 'tool_result', tool_use_id: 'call-1', content: 'a.txt' }] } },
  { type: 'attachment', attachment: { type: 'nested_memory', path: '/home/me/project/CLAUDE.md' }, rendered: [{ content: 'nested rules' }] },
  { type: 'attachment', attachment: { type: 'total_tokens_reminder' }, rendered: [{ content: '<total_tokens>9 tokens left</total_tokens>' }] },
  { type: 'user', isSidechain: true, message: { content: 'a subagent prompt' } },
  { type: 'user', isMeta: true, promptId: 'prompt-2', message: { content: [{ type: 'text', text: 'skill body' }] } },
  { type: 'user', uuid: 'p2', promptId: 'prompt-2', message: { role: 'user', content: 'now read it' } },
  { type: 'assistant', message: { content: [{ type: 'tool_use', id: 'call-2', name: 'Read', input: { file_path: '/home/me/project/a.txt' } }] } },
  { type: 'user', toolUseResult: {}, message: { content: [{ type: 'tool_result', tool_use_id: 'call-2', content: 'no such file', is_error: true }] } },
]
  .map(row => JSON.stringify(row))
  .join('\n')

test('a resumed session shows the turns its transcript holds', async ($, on) => {
  mock.env(on, { TMPDIR: '/tmp/context-tree-test/', HOME: '/home/me' })
  on('session.id', () => ({ value: 'test-session' }))
  on('session.cwd', () => ({ value: '/home/me/project' }))
  on('fs.write', () => ({ value: undefined }))
  on('process.run', transcript(HEAD, TURNS))
  on('session.start', () => ({ cwd: '/home/me/project' }))
  on('command.register', () => ({ value: { command: 'context-tree' } }))
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200_000 }, rateLimits: [] } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  await $.session.start({ cwd: '/home/me/project', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'expand' })
  for (const label of ['Turn 1: list the files', '\\$ ls -la', 'nested_memory', 'command_permissions', 'Turn 2: now read it', 'Read /home/me/project/a.txt']) {
    expect(await ui.find({ type: 'Button', text: new RegExp(label) })).toBeDefined()
  }
  for (const label of ['Turn 3', 'subagent prompt', 'skill body', 'total_tokens_reminder']) {
    expect(await ui.find({ type: 'Button', text: new RegExp(label) })).toBeUndefined()
  }
  expect(await ui.find({ text: /on: transcript/ })).toBeDefined()
  await ui.unmount()
})

test('a /resume in the process rebuilds the tree at the next turn', async ($, on) => {
  mock.env(on, { TMPDIR: '/tmp/context-tree-test/', HOME: '/home/me' })
  on('session.id', () => ({ value: 'test-session' }))
  on('session.cwd', () => ({ value: '/home/me/project' }))
  on('fs.write', () => ({ value: undefined }))
  on('process.run', transcript(HEAD, TURNS))
  on('session.end', (_$, e) => ({ sessionId: e.sessionId }))
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false }, text: '' }))
  await $.tool.call({ tool: 'Bash', command: 'echo before' })
  await $.session.end({ reason: 'resume', sessionId: 'old-session', resume: { id: 'old-session' } })
  await $.turn.start({ text: 'now read it', turnId: 'live-turn' })

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'expand' })
  expect(await ui.find({ type: 'Button', text: /echo before/ })).toBeUndefined()
  expect(await ui.find({ type: 'Button', text: /Turn 1: list the files/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', text: /Turn 2: now read it/ })).toBeDefined()
  expect(await ui.find({ type: 'Button', text: /Turn 3/ })).toBeUndefined()
  await ui.unmount()
})
