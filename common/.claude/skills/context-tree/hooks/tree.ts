import type { CtxNode } from '../types'

// The functions here are pure: they take the tree and answer a new one, or
// answer drafts of nodes. A module cannot pass `$` across an import, so
// register.tsx does the reads, the writes and the captures.

export const START = 'start'
export const START_FILES = 'start:files'
export const START_BLOCKS = 'start:blocks'
export const START_SYSTEM = 'start:system'
export const START_ATTACHMENTS = 'start:attachments'
export const START_TOOLS = 'start:tools'

// Attachments that describe the session, not the prompt that carried them.
// The session start node reads them from the transcript, so the turn skips them.
export const START_TYPES = new Set([
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
export const HIDDEN_TYPES = new Set(['total_tokens_reminder'])
// Attachment rows the session start node shows in a group of their own.
export const START_OWN_GROUP = new Set(['instructions', 'session_context', 'prompt_snapshot'])

/** A node before its capture file exists: `capture` holds the text to write. */
export type Draft = Omit<CtxNode, 'children'> & { capture?: { file: string; text: string }; children: Draft[] }

export const node = (label: string, extra: Partial<CtxNode> = {}): CtxNode => ({
  id: crypto.randomUUID(),
  label,
  children: [],
  ...extra,
})

const group = (id: string, label: string, event: string): CtxNode => ({ id, label, event, children: [] })

export const startNode = (event: string): CtxNode => ({
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

/** A capture node: the viewer opens the file that register.tsx writes for it. */
export const captureDraft = (event: string, label: string, file: string, text: string, hint?: string): Draft => ({
  ...node(label, { hint, event }),
  capture: { file, text },
})

export const tokens = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k tok` : `${n} tok`)

export const firstLine = (text: string, max = 80) => {
  const line = text.trim().split('\n')[0] ?? ''
  return line.length > max ? `${line.slice(0, max - 1)}…` : line
}

export const estimate = (text: string) => `~${tokens(Math.ceil(text.length / 4))}`

/** The tree with the session start node first. */
export const withStart = (list: CtxNode[], event: string): CtxNode[] =>
  list.some(n => n.id === START) ? list : [startNode(event), ...list]

/** Adds a node under the current turn, or under a subagent group inside it. */
export const addToTurn = (list: CtxNode[], child: CtxNode, event: string, agentId?: string): CtxNode[] => {
  const full = withStart(list, event)
  // The last turn, or the session start node before the first turn.
  const root = full[full.length - 1]?.id ?? START
  if (!agentId) return mapNode(full, root, n => ({ ...n, children: [...n.children, child] }))
  const agentGroup = `${root}:agent:${agentId}`
  return mapNode(full, root, n => {
    const has = n.children.some(c => c.id === agentGroup)
    const children = has ? n.children : [...n.children, group(agentGroup, `subagent ${agentId.slice(0, 8)}`, event)]
    return { ...n, children: mapNode(children, agentGroup, g => ({ ...g, children: [...g.children, child] })) }
  })
}

/** The number of turns in the tree. */
export const turnCount = (list: CtxNode[]) => list.filter(n => n.id !== START).length

/** A turn with its prompt and the mentions the prompt held. */
export const turnDraft = (number: number, id: string, event: string, text?: string, children: Draft[] = []): Draft => {
  const title = text ? firstLine(text, 60) : '(continuation)'
  const prompt = text ? [captureDraft(event, 'prompt', 'prompt.txt', text)] : []
  return { id, label: `Turn ${number}: ${title}`, event, children: [...prompt, ...children] }
}

export const mentionNode = (mention: string, path: string, offset?: number): CtxNode =>
  node(`@${mention}`, { path, line: offset, event: 'prompt.mention' })

export type AttachmentInput = { type: string; text: string; agentId?: string; hookEvent?: string }

/** The node for an attachment, or nothing when the session start node holds it or the tree hides it. */
export const attachmentDraft = (isFirstTurn: boolean, a: AttachmentInput, event: string): Draft | undefined => {
  const label = a.hookEvent ? `${a.type} (${a.hookEvent} hook)` : a.type
  const isStart = !a.agentId && (a.hookEvent === 'SessionStart' || (isFirstTurn && START_TYPES.has(a.type)))
  if (isStart || HIDDEN_TYPES.has(a.type)) return undefined
  return captureDraft(event, label, `${a.type}.txt`, a.text, estimate(a.text))
}

export type ToolRun = { deny?: string; text?: string; result?: unknown; isError?: boolean }

/** The node for a tool call: its input, and its output or the reason for the deny. */
export const toolDraft = (e: Record<string, unknown>, ran: ToolRun, event: string): Draft => {
  const tool = String(e.tool)
  if (ran.deny !== undefined) return node(`${tool} (denied)`, { hint: firstLine(ran.deny, 60), event })
  const out = ran.text ?? JSON.stringify(ran.result, null, 2) ?? ''
  const str = (k: string) => (typeof e[k] === 'string' ? (e[k] as string) : undefined)
  const num = (k: string) => (typeof e[k] === 'number' ? (e[k] as number) : undefined)
  const err = ran.isError === true ? 'error' : undefined
  const filePath = str('file_path') ?? str('notebook_path')
  if (filePath && ['Read', 'Write', 'Edit', 'MultiEdit', 'NotebookEdit'].includes(tool)) {
    const offset = num('offset')
    const label = `${tool} ${filePath}${offset ? `:${offset}` : ''}`
    return node(label, { path: filePath, line: offset, hint: err, event })
  }
  const input = { ...e }
  for (const k of ['tool', 'tool_use_id', 'agentId', 'consent']) delete input[k]
  const output = captureDraft(event, 'output', 'output.txt', out, tokens(Math.ceil(out.length / 4)))
  if (tool === 'Bash') {
    const command = str('command') ?? ''
    return {
      ...node(`$ ${firstLine(command)}`, { hint: err ?? str('description'), event }),
      children: [captureDraft(event, 'command', 'command.sh', command), output],
    }
  }
  const summary = str('pattern') ?? str('url') ?? str('skill') ?? str('description') ?? str('query') ?? str('path') ?? ''
  return {
    ...node(`${tool} ${firstLine(summary, 60)}`.trim(), { hint: err, event }),
    children: [captureDraft(event, 'input', 'input.json', JSON.stringify(input, null, 2)), output],
  }
}

type MemoryFile = { path: string; type: string; tokens: number }

/** Puts the token counts of the context breakdown on the instruction files. */
export const annotateUsage = (list: CtxNode[], memoryFiles: MemoryFile[], event: string): CtxNode[] => {
  const byPath = new Map(memoryFiles.map(f => [f.path, f]))
  if (byPath.size === 0) return list
  if (findNode(list, START_FILES)?.children.length === 0) {
    // The transcript has not filled the session start node yet: list the files the breakdown knows.
    const files = [...byPath.values()].map(f => node(f.path, { path: f.path, hint: `${f.type} · ${tokens(f.tokens)}`, event }))
    return mapNode(list, START_FILES, g => ({ ...g, children: files }))
  }
  const annotate = (nodes: CtxNode[]): CtxNode[] =>
    nodes.map(n => {
      const f = n.path ? byPath.get(n.path) : undefined
      const hint = f ? `${n.hint?.split(' · ')[0] ?? f.type} · ${tokens(f.tokens)}` : n.hint
      return { ...n, hint, children: annotate(n.children) }
    })
  return mapNode(list, START_FILES, g => ({ ...g, children: annotate(g.children) }))
}

/** True when the transcript filled the session start node. */
export const isStartFilled = (list: CtxNode[]) => Boolean(findNode(list, START)?.hint)

/** The tree with `children` in the session start node. */
export const fillStart = (list: CtxNode[], children: CtxNode[]) =>
  mapNode(list, START, n => ({ ...n, hint: 'from the transcript', children }))

/** The tree with `turns` after the session start node and before the turns it holds. */
export const prependTurns = (list: CtxNode[], turns: CtxNode[], event: string) => {
  const [start, ...rest] = withStart(list, event)
  return [start!, ...turns, ...rest]
}
