import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CtxNode, CtxView } from '../types'

const PANE = 'context-tree'
const VIEW = 'context-view'
const START = 'start'
const START_FILES = 'start:files'
const START_BLOCKS = 'start:blocks'
const START_SYSTEM = 'start:system'
const START_ATTACHMENTS = 'start:attachments'
const START_TOOLS = 'start:tools'

// Attachments that describe the session, not the prompt that carried them.
// The session start node reads them from the transcript, so the turn skips them.
const START_TYPES = new Set([
  'skill_listing',
  'deferred_tools_delta',
  'mcp_instructions',
  'mcp_instructions_delta',
  'agent_listing_delta',
  'environment',
  'model',
  'auto_mode',
  'date',
  'remote_session_change',
])
// Attachments the tree never shows, at the session start or in a turn.
const HIDDEN_TYPES = new Set(['total_tokens_reminder'])
// Attachment rows the session start node shows in a group of their own.
const START_OWN_GROUP = new Set(['instructions', 'session_context', 'prompt_snapshot'])

// Prints the transcript up to the first prompt snapshot that lists the tools:
// the rows of the session start and the first prompt.
const HEAD_AWK = '{ print } /"prompt_snapshot"/ && /"tools":\\[/ { exit } NR >= 400 { exit }'
const VIEW_LIMIT = 100_000

const tree = atom({ plugin: 'context-tree', key: 'tree' } as const, [])
const expanded = atom({ plugin: 'context-tree', key: 'expanded' } as const, [START])
const viewing = atom({ plugin: 'context-tree', key: 'viewing' } as const, null)
const pending = atom({ plugin: 'context-tree', key: 'pending' } as const, [])
const usage = atom({ plugin: 'context-tree', key: 'usage' } as const, null)

type $ = EngineInterface

const node = (label: string, extra: Partial<CtxNode> = {}): CtxNode => ({
  id: crypto.randomUUID(),
  label,
  children: [],
  ...extra,
})

const group = (id: string, label: string, event: string): CtxNode => ({ id, label, event, children: [] })

const startNode = (event: string): CtxNode => ({
  id: START,
  label: 'Session start',
  event,
  children: [
    group(START_FILES, 'Instruction files', event),
    group(START_BLOCKS, 'Context blocks', event),
    group(START_SYSTEM, 'System prompt', event),
    group(START_TOOLS, 'Tool schemas', event),
    group(START_ATTACHMENTS, 'Attachments', event),
  ],
})

/** Applies `fn` to the node with `id`, wherever it sits. */
const mapNode = (list: CtxNode[], id: string, fn: (n: CtxNode) => CtxNode): CtxNode[] =>
  list.map(n => (n.id === id ? fn(n) : { ...n, children: mapNode(n.children, id, fn) }))

const findNode = (list: CtxNode[], id: string): CtxNode | undefined => {
  for (const n of list) {
    if (n.id === id) return n
    const hit = findNode(n.children, id)
    if (hit) return hit
  }
  return undefined
}

const setChildren = ($: $, id: string, children: CtxNode[]) =>
  update($, tree, list => mapNode(list, id, n => ({ ...n, children })))

const addChild = ($: $, id: string, child: CtxNode) =>
  update($, tree, list => mapNode(list, id, n => ({ ...n, children: [...n.children, child] })))

/** The last turn, or the session start node before the first turn. */
const currentRoot = (list: CtxNode[]) => list[list.length - 1]?.id ?? START

/** Adds a node under the current turn, or under a subagent group inside it. */
const addToTurn = async ($: $, child: CtxNode, event: string, agentId?: string) => {
  await ensureStart($, event)
  const root = currentRoot(await read($, tree))
  if (!agentId) return addChild($, root, child)
  const agentGroup = `${root}:agent:${agentId}`
  await update($, tree, list =>
    mapNode(list, root, n => {
      const has = n.children.some(c => c.id === agentGroup)
      const children = has
        ? n.children
        : [...n.children, group(agentGroup, `subagent ${agentId.slice(0, 8)}`, event)]
      return { ...n, children: mapNode(children, agentGroup, g => ({ ...g, children: [...g.children, child] })) }
    }),
  )
}

/** Writes text to a capture file of this session and answers its path. */
const capture = async ($: $, name: string, text: string) => {
  const tmp = ((await $.env.get('TMPDIR')) ?? '/tmp/').replace(/\/?$/, '/')
  const dir = `${tmp}claude-context-tree/${await $.session.id()}`
  const path = `${dir}/${Date.now()}-${crypto.randomUUID().slice(0, 6)}-${name}`
  await $.fs.write(path, text)
  return path
}

const captureNode = async ($: $, event: string, label: string, file: string, text: string, hint?: string) =>
  node(label, { path: await capture($, file, text), isCapture: true, hint, event })

const tokens = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k tok` : `${n} tok`)

const firstLine = (text: string, max = 80) => {
  const line = text.trim().split('\n')[0] ?? ''
  return line.length > max ? `${line.slice(0, max - 1)}…` : line
}

const ensureStart = async ($: $, event: string) => {
  if ((await read($, tree)).some(n => n.id === START)) return
  await update($, tree, list => [startNode(event), ...list.filter(n => n.id !== START)])
}

/** Reads the token counts the context breakdown gives, by memory file path. */
const refreshUsage = async ($: $, event: string) => {
  const now = await $.session.usage({ breakdown: 'summary' })
  const { percent, tokens: used, window, breakdown } = now.context
  await update($, usage, () => ({ percent, tokens: used, window }))
  const byPath = new Map((breakdown?.memoryFiles ?? []).map(f => [f.path, f]))
  if (byPath.size === 0) return
  const files = findNode(await read($, tree), START_FILES)
  if (files && files.children.length === 0) {
    // prompt.context has not run yet: list the files the breakdown knows.
    await setChildren(
      $,
      START_FILES,
      [...byPath.values()].map(f => node(f.path, { path: f.path, hint: `${f.type} · ${tokens(f.tokens)}`, event })),
    )
    return
  }
  const annotate = (list: CtxNode[]): CtxNode[] =>
    list.map(n => {
      const f = n.path ? byPath.get(n.path) : undefined
      const hint = f ? `${n.hint?.split(' · ')[0] ?? f.type} · ${tokens(f.tokens)}` : n.hint
      return { ...n, hint, children: annotate(n.children) }
    })
  await update($, tree, list => mapNode(list, START_FILES, g => ({ ...g, children: annotate(g.children) })))
}

type Attachment = Record<string, unknown> & { type: string }
type Row = { type?: string; attachment?: Attachment; rendered?: { content?: unknown }[] }

const estimate = (text: string) => `~${tokens(Math.ceil(text.length / 4))}`

/** The text the model read for a transcript row, as the engine rendered it. */
const renderedText = (row: Row) =>
  (row.rendered ?? [])
    .map(r =>
      typeof r.content === 'string'
        ? r.content
        : Array.isArray(r.content)
          ? r.content.map(b => (typeof b?.text === 'string' ? b.text : '')).join('\n')
          : '',
    )
    .join('\n')

/** A short label for a system prompt section: its first heading or line. */
const sectionLabel = (text: string) => firstLine(text.replace(/^\s*#+\s*/, ''), 50) || '(empty)'

/** A group node; `texts` are what its children hold, for the token estimate. */
const groupOf = (id: string, label: string, event: string, children: CtxNode[], texts: string[]): CtxNode => ({
  id,
  label,
  hint: `${children.length} items · ${estimate(texts.join(''))}`,
  event,
  children,
})

const transcriptPath = async ($: $) => {
  const config = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`
  const slug = (await $.session.cwd()).replace(/[^a-zA-Z0-9]/g, '-')
  return `${config}/projects/${slug}/${await $.session.id()}.jsonl`
}

let loading: Promise<void> | undefined

/** Fills the session start node from the head of the transcript, once per conversation. */
const loadStart = ($: $, event: string) => {
  loading ??= fillStart($, event).finally(() => {
    loading = undefined
  })
  return loading
}

const fillStart = async ($: $, event: string) => {
  await ensureStart($, event)
  if (findNode(await read($, tree), START)?.hint) return
  const head = await $.process.run(['awk', HEAD_AWK, await transcriptPath($)]).catch(() => undefined)
  if (!head || head.exitCode !== 0) return
  const rows: Row[] = head.stdout.split('\n').flatMap(line => {
    try {
      return [JSON.parse(line) as Row]
    } catch {
      return []
    }
  })
  let snapshot: Attachment | undefined
  let tools: unknown[] = []
  const atts: Row[] = []
  for (const row of rows) {
    const a = row.attachment
    if (row.type !== 'attachment' || !a) continue
    if (a.type === 'prompt_snapshot') {
      snapshot ??= a
      if (Array.isArray(a.tools)) {
        tools = a.tools
        break
      }
    } else if (!snapshot) {
      // Rows after the first snapshot belong to the first turn.
      atts.push(row)
    }
  }
  if (!snapshot) return

  const instructions = atts.find(r => r.attachment?.type === 'instructions')?.attachment
  const fileList = Array.isArray(instructions?.files) ? (instructions.files as { path: string; type: string; content: string }[]) : []
  const files = fileList.map(f => node(f.path, { path: f.path, hint: `${f.type} · ${estimate(f.content)}`, event }))

  const context = atts.find(r => r.attachment?.type === 'session_context')?.attachment?.context
  const blockTexts = Object.entries((context ?? {}) as Record<string, unknown>).map(([name, value]) => ({
    name,
    text: typeof value === 'string' ? value : JSON.stringify(value, null, 2),
  }))
  const blocks = await Promise.all(blockTexts.map(b => captureNode($, event, b.name, `${b.name}.md`, b.text, estimate(b.text))))

  const prefix = typeof snapshot.cliPrefix === 'string' ? [snapshot.cliPrefix] : []
  const sections = [...prefix, ...(Array.isArray(snapshot.systemPrompt) ? (snapshot.systemPrompt as string[]) : [])]
  const system = await Promise.all(
    sections.map((text, i) => captureNode($, event, sectionLabel(text), `system-${i}.md`, text, estimate(text))),
  )

  const toolTexts = tools.map(t => ({
    name: String((t as { name?: unknown }).name ?? 'tool'),
    text: JSON.stringify(t, null, 2),
  }))
  const schemas = await Promise.all(
    toolTexts.map(t => captureNode($, event, t.name, `tool-${t.name.replace(/[^\w-]/g, '_')}.json`, t.text, estimate(t.text))),
  )

  const attTexts = atts
    .filter(r => r.attachment && !START_OWN_GROUP.has(r.attachment.type) && !HIDDEN_TYPES.has(r.attachment.type))
    .map(r => ({ type: r.attachment!.type, text: renderedText(r) }))
    .filter(r => r.text)
  const attachments = await Promise.all(attTexts.map(r => captureNode($, event, r.type, `${r.type}.md`, r.text, estimate(r.text))))

  const children = [
    groupOf(START_FILES, 'Instruction files', event, files, fileList.map(f => f.content)),
    groupOf(START_BLOCKS, 'Context blocks', event, blocks, blockTexts.map(b => b.text)),
    groupOf(START_SYSTEM, 'System prompt', event, system, sections),
    groupOf(START_TOOLS, 'Tool schemas', event, schemas, toolTexts.map(t => t.text)),
    groupOf(START_ATTACHMENTS, 'Attachments', event, attachments, attTexts.map(r => r.text)),
  ]
  await update($, tree, list => mapNode(list, START, n => ({ ...n, hint: 'from the transcript', children })))
  await refreshUsage($, event)
}

const toolNode = async ($: $, e: Record<string, unknown>, tool: string, out: string, isError: boolean) => {
  const str = (k: string) => (typeof e[k] === 'string' ? (e[k] as string) : undefined)
  const num = (k: string) => (typeof e[k] === 'number' ? (e[k] as number) : undefined)
  const err = isError ? 'error' : undefined
  const filePath = str('file_path') ?? str('notebook_path')
  if (filePath && ['Read', 'Write', 'Edit', 'MultiEdit', 'NotebookEdit'].includes(tool)) {
    const offset = num('offset')
    const label = `${tool} ${filePath}${offset ? `:${offset}` : ''}`
    return node(label, { path: filePath, line: offset, hint: err, event: 'tool.call' })
  }
  const input = { ...e }
  for (const k of ['tool', 'tool_use_id', 'agentId', 'consent']) delete input[k]
  if (tool === 'Bash') {
    const command = str('command') ?? ''
    return node(`$ ${firstLine(command)}`, {
      hint: err ?? str('description'),
      event: 'tool.call',
      children: [
        await captureNode($, 'tool.call', 'command', 'command.sh', command),
        await captureNode($, 'tool.call', 'output', 'output.txt', out, tokens(Math.ceil(out.length / 4))),
      ],
    })
  }
  const summary = str('pattern') ?? str('url') ?? str('skill') ?? str('description') ?? str('query') ?? str('path') ?? ''
  return node(`${tool} ${firstLine(summary, 60)}`.trim(), {
    hint: err,
    event: 'tool.call',
    children: [
      await captureNode($, 'tool.call', 'input', 'input.json', JSON.stringify(input, null, 2)),
      await captureNode($, 'tool.call', 'output', 'output.txt', out, tokens(Math.ceil(out.length / 4))),
    ],
  })
}

const shellQuote = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`

/** Opens the file in nvim, in a new herdr pane to the right of this one. */
const openInHerdr = async ($: $, view: CtxView) => {
  const pane = await $.env.get('HERDR_PANE_ID')
  if (!pane) {
    $.ui.toast('context-tree: HERDR_PANE_ID is not set; run Claude Code inside herdr')
    return
  }
  const bin = (await $.env.get('HERDR_BIN_PATH')) ?? 'herdr'
  const split = await $.process.run([bin, 'pane', 'split', pane, '--direction', 'right', '--focus'])
  const id: unknown = split.exitCode === 0 ? JSON.parse(split.stdout)?.result?.pane?.pane_id : undefined
  if (typeof id !== 'string') {
    $.ui.toast(`context-tree: herdr pane split failed: ${firstLine(split.stderr || split.stdout)}`)
    return
  }
  const args = [view.isCapture ? '-R' : '', view.line ? `+${view.line}` : '', shellQuote(view.path)]
  await $.process.run([bin, 'pane', 'run', id, `exec nvim ${args.filter(Boolean).join(' ')}`])
}

const openViewer = async ($: $, view: CtxView) => {
  await update($, viewing, () => view)
  await $.ui.open({ id: VIEW, title: view.label.slice(0, 60), focus: true, closeOnEscape: true, holdToasts: true })
}

const LANGS: Record<string, string> = {
  ts: 'typescript', tsx: 'tsx', js: 'javascript', json: 'json', md: 'markdown', sh: 'bash',
  py: 'python', go: 'go', rs: 'rust', lua: 'lua', toml: 'toml', yaml: 'yaml', yml: 'yaml',
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'context-tree', description: 'Show the context window as a tree in a pane' })
    await ensureStart($, 'session.start')
    void loadStart($, 'session.start').then(() => refreshUsage($, 'session.start')).catch(() => undefined)
    void $.ui.open({ id: PANE, title: 'Context' })
    return next(e)
  })

  on('command.run', { command: 'context-tree' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Context' })
    return { text: 'Context tree opened.' }
  })

  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') {
      await update($, tree, () => [startNode('session.end')])
      await update($, expanded, () => [START])
      await update($, usage, () => null)
    }
    return next(e)
  })

  on('prompt.attachment', async ($, e, next) => {
    const out = await next(e)
    if (out.text === null) return out
    const text = out.text ?? e.text
    const list = await read($, tree)
    const isFirstTurn = list.filter(n => n.id !== START).length <= 1
    const fromHook = e.origin.kind === 'hook' ? e.origin.event : undefined
    const label = fromHook ? `${e.type} (${fromHook} hook)` : e.type
    const isStart = !e.agentId && (fromHook === 'SessionStart' || (isFirstTurn && START_TYPES.has(e.type)))
    if (isStart || HIDDEN_TYPES.has(e.type)) return out
    const n = await captureNode($, 'prompt.attachment', label, `${e.type}.txt`, text, estimate(text))
    await addToTurn($, n, 'prompt.attachment', e.agentId)
    return out
  })

  on('prompt.mention', async ($, e, next) => {
    const out = await next(e)
    if (!e.agentId) {
      const n = node(`@${e.mention}`, { path: e.path, line: e.offset, event: 'prompt.mention' })
      await update($, pending, list => [...list, n])
    }
    return out
  }).catch(($, e, next) => next(e))

  on('turn.start', async ($, e, next) => {
    const out = await next(e)
    await ensureStart($, 'turn.start')
    const count = (await read($, tree)).filter(n => n.id !== START).length + 1
    const title = e.text ? firstLine(e.text, 60) : '(continuation)'
    const prompt = e.text ? [await captureNode($, 'turn.start', 'prompt', 'prompt.txt', e.text)] : []
    const mentions = await read($, pending)
    await update($, pending, () => [])
    await update($, tree, list => [
      ...list,
      { id: e.turnId, label: `Turn ${count}: ${title}`, event: 'turn.start', children: [...prompt, ...mentions] },
    ])
    return out
  })

  on('turn.complete', async ($, e, next) => {
    const out = await next(e)
    void loadStart($, 'turn.complete').then(() => refreshUsage($, 'turn.complete')).catch(() => undefined)
    return out
  })

  on('tool.call', async ($, e, next) => {
    const ran = await next(e)
    void loadStart($, 'tool.call').catch(() => undefined)
    if ('deny' in ran && ran.deny !== undefined) {
      await addToTurn($, node(`${e.tool} (denied)`, { hint: firstLine(ran.deny, 60), event: 'tool.call' }), 'tool.call', e.agentId)
      return ran
    }
    const out = ran.text ?? JSON.stringify(ran.result, null, 2) ?? ''
    const n = await toolNode($, e as unknown as Record<string, unknown>, String(e.tool), out, ran.isError === true)
    await addToTurn($, n, 'tool.call', e.agentId)
    return ran
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const list = await read($, tree)
    const open = new Set(await read($, expanded))
    const now = await read($, usage)
    const width = e.props.bodyColumns

    const toggle = (id: string) =>
      update($, expanded, ids => (ids.includes(id) ? ids.filter(x => x !== id) : [...ids, id]))

    const rows: JSX.Element[] = []
    const walk = (nodes: CtxNode[], depth: number) => {
      for (const n of nodes) {
        const hasKids = n.children.length > 0
        // The `on:` row makes a node with an event open, even without children.
        const canOpen = hasKids || n.event !== undefined
        const isOpen = open.has(n.id)
        const mark = canOpen ? (isOpen ? '▾ ' : '▸ ') : '  '
        const indent = '  '.repeat(depth)
        const view: CtxView | undefined = n.path
          ? { label: n.label, path: n.path, line: n.line, isCapture: n.isCapture }
          : undefined
        // A leaf with a view opens the viewer from its label, so its mark toggles on its own.
        const isMarkSplit = !hasKids && view !== undefined && canOpen
        const room = Math.max(8, width - indent.length - 4)
        const text = isMarkSplit ? n.label : `${mark}${n.label}`
        const label = text.length > room ? `${text.slice(0, room - 1)}…` : text
        rows.push(
          <Box key={`row:${n.id}`} flexDirection="column">
            <Box flexDirection="row">
              <Text>{indent}</Text>
              {isMarkSplit && (
                <Button key={`t:${n.id}`} plain onPress={() => toggle(n.id)}>
                  {mark}
                </Button>
              )}
              <Button
                key={`n:${n.id}`}
                plain
                dimColor={!canOpen && !view}
                onPress={() => (hasKids ? toggle(n.id) : view ? openViewer($, view) : canOpen ? toggle(n.id) : undefined)}
              >
                {label}
              </Button>
              {view && (
                <Button key={`o:${n.id}`} plain dimColor onPress={() => openInHerdr($, view)}>
                  {' ↗'}
                </Button>
              )}
            </Box>
            {n.hint && (
              <Text dimColor wrap="truncate-end">
                {`${indent}    ${n.hint}`}
              </Text>
            )}
          </Box>,
        )
        if (!isOpen) continue
        if (n.event) {
          rows.push(
            <Text key={`on:${n.id}`} dimColor wrap="truncate-end">
              {`${indent}    on: ${n.event}`}
            </Text>,
          )
        }
        walk(n.children, depth + 1)
      }
    }
    walk(list, 0)

    const fill = now
      ? `${now.percent ?? '?'}% · ${now.tokens ? tokens(now.tokens) : '?'} of ${tokens(now.window)}`
      : 'no usage yet'

    return (
      <Box flexDirection="column">
        <Box flexDirection="row" gap={1}>
          <Text bold>Context</Text>
          <Text dimColor>{fill}</Text>
        </Box>
        <Box flexDirection="row" gap={1}>
          <Button key="expand" plain dimColor onPress={() => update($, expanded, () => allIds(list))}>
            expand all
          </Button>
          <Button key="collapse" plain dimColor onPress={() => update($, expanded, () => [])}>
            collapse all
          </Button>
        </Box>
        {rows}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: VIEW }, async ($, e) => {
    const { Box, Text, Button, Code } = $.ui.resolve(e)
    const view = await read($, viewing)
    if (!view) return <Text dimColor>Nothing selected.</Text>
    let source: string
    try {
      source = await $.fs.read(view.path)
    } catch (err) {
      source = `Cannot read ${view.path}: ${String(err)}`
    }
    const isCut = source.length > VIEW_LIMIT
    const ext = view.path.split('.').pop() ?? ''
    return (
      <Box flexDirection="column">
        <Box flexDirection="row" gap={1}>
          <Button key="nvim" hotkey="o" autoFocus onPress={() => openInHerdr($, view)}>
            open in nvim
          </Button>
          <Button key="close" hotkey="q" role="dismiss" onPress={() => $.ui.close({ id: VIEW })}>
            close
          </Button>
        </Box>
        <Text dimColor wrap="truncate-start">{view.path}</Text>
        {isCut && <Text color="warning">{`Shows the first ${VIEW_LIMIT} characters; open in nvim for the rest.`}</Text>}
        <Code source={source.slice(0, VIEW_LIMIT)} language={LANGS[ext]} startLine={1} />
      </Box>
    )
  })
}

const allIds = (list: CtxNode[]): string[] => list.flatMap(n => (n.children.length || n.event ? [n.id, ...allIds(n.children)] : []))
