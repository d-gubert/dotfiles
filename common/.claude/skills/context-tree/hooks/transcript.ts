import {
  HIDDEN_TYPES,
  START_ATTACHMENTS,
  START_BLOCKS,
  START_FILES,
  START_OWN_GROUP,
  START_SYSTEM,
  START_TOOLS,
  attachmentDraft,
  captureDraft,
  estimate,
  firstLine,
  node,
  toolDraft,
  turnDraft,
} from './tree'
import type { Draft } from './tree'

// Reads the session transcript (the jsonl file) into drafts of the tree.
// register.tsx runs the reads; the functions here only parse what they print.

/** The event the tree shows on the nodes it rebuilt from the transcript. */
const EVENT = 'transcript'

// Prints the transcript up to the first prompt snapshot that lists the tools:
// the rows of the session start and the first prompt.
export const HEAD_AWK = '{ print } /"prompt_snapshot"/ && /"tools":\\[/ { exit } NR >= 400 { exit }'

// Prints the lines after line `from` until they hold about `max` characters.
// A read of the engine stops at 4 MiB, so register.tsx reads the file in chunks.
export const CHUNK_AWK = 'NR > from { print; n += length($0) + 1; if (n >= max) exit }'
export const CHUNK_CHARS = 3 * 1024 * 1024

/**
 * The complete lines of a chunk, and the number of lines it moves past.
 * A cut chunk ends in a part of a line over the read limit: the read skips that line.
 */
export const chunkLines = (stdout: string, isCut: boolean) => {
  const lines = stdout.split('\n')
  // A chunk that is not cut ends with a newline; a cut chunk ends with the part of a line.
  lines.pop()
  return { lines, consumed: lines.length + (isCut ? 1 : 0) }
}

type Attachment = Record<string, unknown> & { type: string }
type Block = { type?: string; text?: unknown; id?: string; name?: string; input?: unknown; tool_use_id?: string; content?: unknown; is_error?: boolean }
type Row = {
  type?: string
  uuid?: string
  promptId?: string
  isMeta?: boolean
  isSidechain?: boolean
  toolUseResult?: unknown
  message?: { content?: string | Block[] }
  attachment?: Attachment
  rendered?: { content?: unknown }[]
}

const parseRows = (lines: string[]): Row[] =>
  lines.flatMap(line => {
    try {
      return [JSON.parse(line) as Row]
    } catch {
      return []
    }
  })

/** The text of a message content: a string, or the text of its blocks. */
const contentText = (content: unknown) =>
  typeof content === 'string'
    ? content
    : Array.isArray(content)
      ? content.map(b => (typeof b?.text === 'string' ? b.text : '')).join('\n')
      : ''

/** The text the model read for a transcript row, as the engine rendered it. */
const renderedText = (row: Row) => (row.rendered ?? []).map(r => contentText(r.content)).join('\n')

/** A short label for a system prompt section: its first heading or line. */
const sectionLabel = (text: string) => firstLine(text.replace(/^\s*#+\s*/, ''), 50) || '(empty)'

/** A group node; `texts` are what its children hold, for the token estimate. */
const groupOf = (id: string, label: string, event: string, children: Draft[], texts: string[]): Draft => ({
  id,
  label,
  hint: `${children.length} items · ${estimate(texts.join(''))}`,
  event,
  children,
})

/** The groups of the session start node, from the head of the transcript; nothing before the first snapshot. */
export const startDrafts = (text: string, event: string): Draft[] | undefined => {
  let snapshot: Attachment | undefined
  let tools: unknown[] = []
  const atts: Row[] = []
  for (const row of parseRows(text.split('\n'))) {
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
  if (!snapshot) return undefined

  const instructions = atts.find(r => r.attachment?.type === 'instructions')?.attachment
  const fileList = Array.isArray(instructions?.files) ? (instructions.files as { path: string; type: string; content: string }[]) : []
  const files = fileList.map(f => node(f.path, { path: f.path, hint: `${f.type} · ${estimate(f.content)}`, event }))

  const context = atts.find(r => r.attachment?.type === 'session_context')?.attachment?.context
  const blockTexts = Object.entries((context ?? {}) as Record<string, unknown>).map(([name, value]) => ({
    name,
    text: typeof value === 'string' ? value : JSON.stringify(value, null, 2),
  }))
  const blocks = blockTexts.map(b => captureDraft(event, b.name, `${b.name}.md`, b.text, estimate(b.text)))

  const prefix = typeof snapshot.cliPrefix === 'string' ? [snapshot.cliPrefix] : []
  const sections = [...prefix, ...(Array.isArray(snapshot.systemPrompt) ? (snapshot.systemPrompt as string[]) : [])]
  const system = sections.map((text, i) => captureDraft(event, sectionLabel(text), `system-${i}.md`, text, estimate(text)))

  const toolTexts = tools.map(t => ({
    name: String((t as { name?: unknown }).name ?? 'tool'),
    text: JSON.stringify(t, null, 2),
  }))
  const schemas = toolTexts.map(t =>
    captureDraft(event, t.name, `tool-${t.name.replace(/[^\w-]/g, '_')}.json`, t.text, estimate(t.text)),
  )

  const attTexts = atts
    .filter(r => r.attachment && !START_OWN_GROUP.has(r.attachment.type) && !HIDDEN_TYPES.has(r.attachment.type))
    .map(r => ({ type: r.attachment!.type, text: renderedText(r) }))
    .filter(r => r.text)
  const attachments = attTexts.map(r => captureDraft(event, r.type, `${r.type}.md`, r.text, estimate(r.text)))

  return [
    groupOf(START_FILES, 'Instruction files', event, files, fileList.map(f => f.content)),
    groupOf(START_BLOCKS, 'Context blocks', event, blocks, blockTexts.map(b => b.text)),
    groupOf(START_SYSTEM, 'System prompt', event, system, sections),
    groupOf(START_TOOLS, 'Tool schemas', event, schemas, toolTexts.map(t => t.text)),
    groupOf(START_ATTACHMENTS, 'Attachments', event, attachments, attTexts.map(r => r.text)),
  ]
}

/** The turns without a last turn that holds `prompt`: the turn that starts now and has its row in the file. */
export const withoutPrompt = (turns: Draft[], prompt: string) =>
  turns.at(-1)?.children[0]?.capture?.text === prompt ? turns.slice(0, -1) : turns

/** True for a prompt that a person or a command sent, not a tool result or a row the engine added. */
const isPrompt = (row: Row) => {
  if (row.type !== 'user' || row.isMeta || row.toolUseResult !== undefined) return false
  const content = row.message?.content
  return typeof content === 'string' || (Array.isArray(content) && !content.some(b => b.type === 'tool_result'))
}

/**
 * The turns of the main thread: each prompt, then its tool calls and attachments.
 * The subagents write their rows to other files, so their calls are not in the turns.
 */
export const turnDrafts = (lines: string[]): Draft[] => {
  const turns: Draft[] = []
  const calls = new Map<string, { name: string; input: Record<string, unknown> }>()
  for (const row of parseRows(lines)) {
    if (row.isSidechain) continue
    const turn = turns[turns.length - 1]
    if (isPrompt(row)) {
      const text = contentText(row.message?.content)
      if (text.trim()) turns.push(turnDraft(turns.length + 1, row.promptId ?? row.uuid ?? crypto.randomUUID(), EVENT, text))
      continue
    }
    // The rows before the first prompt belong to the session start node.
    if (!turn) continue
    const content = row.message?.content
    if (row.type === 'assistant' && Array.isArray(content)) {
      for (const b of content) {
        if (b.type === 'tool_use' && b.id && b.name) calls.set(b.id, { name: b.name, input: (b.input ?? {}) as Record<string, unknown> })
      }
    } else if (row.type === 'user' && Array.isArray(content)) {
      for (const b of content) {
        const call = b.type === 'tool_result' && b.tool_use_id ? calls.get(b.tool_use_id) : undefined
        if (!call) continue
        const ran = { text: contentText(b.content), isError: b.is_error === true }
        turn.children.push(toolDraft({ ...call.input, tool: call.name }, ran, EVENT))
      }
    } else if (row.type === 'attachment' && row.attachment && !START_OWN_GROUP.has(row.attachment.type)) {
      const text = renderedText(row)
      const hookEvent = typeof row.attachment.hookEvent === 'string' ? row.attachment.hookEvent : undefined
      const draft = text && attachmentDraft(turns.length === 1, { type: row.attachment.type, text, hookEvent }, EVENT)
      if (draft) turn.children.push(draft)
    }
  }
  return turns
}
