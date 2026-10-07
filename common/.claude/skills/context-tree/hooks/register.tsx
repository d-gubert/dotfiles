import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { CtxNode, CtxView } from '../types'
import { CHUNK_AWK, CHUNK_CHARS, HEAD_AWK, chunkLines, startDrafts, turnDrafts, withoutPrompt } from './transcript'
import {
  START,
  addToTurn,
  annotateUsage,
  attachmentDraft,
  fillStart,
  firstLine,
  isStartFilled,
  mentionNode,
  prependTurns,
  startNode,
  tokens,
  toolDraft,
  turnCount,
  turnDraft,
  withStart,
} from './tree'
import type { Draft } from './tree'

const PANE = 'context-tree'
const VIEW = 'context-view'
const VIEW_LIMIT = 100_000

const tree = atom({ plugin: 'context-tree', key: 'tree' } as const, [])
const expanded = atom({ plugin: 'context-tree', key: 'expanded' } as const, [START])
const viewing = atom({ plugin: 'context-tree', key: 'viewing' } as const, null)
const pending = atom({ plugin: 'context-tree', key: 'pending' } as const, [])
const usage = atom({ plugin: 'context-tree', key: 'usage' } as const, null)

type $ = EngineInterface

/** Writes text to a capture file of this session and answers its path. */
const capture = async ($: $, name: string, text: string) => {
  const tmp = ((await $.env.get('TMPDIR')) ?? '/tmp/').replace(/\/?$/, '/')
  const dir = `${tmp}claude-context-tree/${await $.session.id()}`
  const path = `${dir}/${Date.now()}-${crypto.randomUUID().slice(0, 6)}-${name}`
  await $.fs.write(path, text)
  return path
}

/** Writes the capture files of a draft and its children, and answers the nodes. */
const materialize = async ($: $, draft: Draft): Promise<CtxNode> => {
  const { capture: text, children, ...n } = draft
  const kids = await Promise.all(children.map(c => materialize($, c)))
  if (!text) return { ...n, children: kids }
  return { ...n, path: await capture($, text.file, text.text), isCapture: true, children: kids }
}

/** Reads the context usage, and the token counts of the instruction files. */
const refreshUsage = async ($: $, event: string) => {
  const now = await $.session.usage({ breakdown: 'summary' })
  const { percent, tokens: used, window, breakdown } = now.context
  await update($, usage, () => ({ percent, tokens: used, window }))
  await update($, tree, list => annotateUsage(list, breakdown?.memoryFiles ?? [], event))
}

const transcriptPath = async ($: $) => {
  const config = (await $.env.get('CLAUDE_CONFIG_DIR')) ?? `${await $.env.get('HOME')}/.claude`
  const slug = (await $.session.cwd()).replace(/[^a-zA-Z0-9]/g, '-')
  return `${config}/projects/${slug}/${await $.session.id()}.jsonl`
}

let loading: Promise<void> | undefined
// True after a /resume in this process: session.start does not fire again, so the next turn rebuilds the tree.
let isResumed = false

/** Fills the session start node from the head of the transcript, once per conversation. */
const loadStart = ($: $, event: string) => {
  loading ??= readStart($, event).finally(() => {
    loading = undefined
  })
  return loading
}

const readStart = async ($: $, event: string) => {
  await update($, tree, list => withStart(list, event))
  if (isStartFilled(await read($, tree))) return
  const head = await $.process.run(['awk', HEAD_AWK, await transcriptPath($)]).catch(() => undefined)
  if (!head || head.exitCode !== 0) return
  const drafts = startDrafts(head.stdout, event)
  if (!drafts) return
  const children = await Promise.all(drafts.map(d => materialize($, d)))
  await update($, tree, list => fillStart(list, children))
  await refreshUsage($, event)
}

/** Reads every line of the transcript, in chunks under the read limit of the engine. */
const readTranscript = async ($: $) => {
  const path = await transcriptPath($)
  const lines: string[] = []
  for (let from = 0; ; ) {
    const chunk = await $.process.run(['awk', '-v', `from=${from}`, '-v', `max=${CHUNK_CHARS}`, CHUNK_AWK, path])
    if (chunk.exitCode !== 0) return undefined
    if (!chunk.stdout) return lines
    const { lines: got, consumed } = chunkLines(chunk.stdout, chunk.isStdoutTruncated)
    if (consumed === 0) return lines
    lines.push(...got)
    from += consumed
  }
}

/**
 * Adds the turns of a resumed conversation from its transcript, before the turns of this process.
 * `prompt` is the prompt of a turn that starts now: the file holds it, and its own hooks add it.
 */
const rebuildTurns = async ($: $, event: string, prompt?: string) => {
  if (turnCount(await read($, tree)) > 0) return
  const lines = await readTranscript($).catch(() => undefined)
  if (!lines) return
  const drafts = turnDrafts(lines)
  const turns = await Promise.all((prompt === undefined ? drafts : withoutPrompt(drafts, prompt)).map(d => materialize($, d)))
  if (turns.length > 0) await update($, tree, list => prependTurns(list, turns, event))
}

/** Adds a draft to the current turn. */
const addDraft = async ($: $, draft: Draft, event: string, agentId?: string) => {
  const n = await materialize($, draft)
  await update($, tree, list => addToTurn(list, n, event, agentId))
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
    await update($, tree, list => withStart(list, 'session.start'))
    void loadStart($, 'session.start').then(() => refreshUsage($, 'session.start')).catch(() => undefined)
    void rebuildTurns($, 'session.start').catch(() => undefined)
    void $.ui.open({ id: PANE, title: 'Context' })
    return next(e)
  })

  on('command.run', { command: 'context-tree' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Context' })
    return { text: 'Context tree opened.' }
  })

  on('session.end', async ($, e, next) => {
    // A /resume in this process loads another conversation: the next turn rebuilds it from its transcript.
    if (e.reason === 'clear' || e.reason === 'resume') {
      await update($, tree, () => [startNode('session.end')])
      await update($, expanded, () => [START])
      await update($, usage, () => null)
      isResumed = e.reason === 'resume'
    }
    return next(e)
  })

  on('prompt.attachment', async ($, e, next) => {
    const out = await next(e)
    if (out.text === null) return out
    const hookEvent = e.origin.kind === 'hook' ? e.origin.event : undefined
    const input = { type: e.type, text: out.text ?? e.text, agentId: e.agentId, hookEvent }
    const draft = attachmentDraft(turnCount(await read($, tree)) <= 1, input, 'prompt.attachment')
    if (draft) await addDraft($, draft, 'prompt.attachment', e.agentId)
    return out
  })

  on('prompt.mention', async ($, e, next) => {
    const out = await next(e)
    if (!e.agentId) await update($, pending, list => [...list, mentionNode(e.mention, e.path, e.offset)])
    return out
  }).catch(($, e, next) => next(e))

  on('turn.start', async ($, e, next) => {
    const out = await next(e)
    if (isResumed) {
      isResumed = false
      await rebuildTurns($, 'turn.start', e.text).catch(() => undefined)
    }
    const mentions = await read($, pending)
    await update($, pending, () => [])
    const turn = await materialize($, turnDraft(turnCount(await read($, tree)) + 1, e.turnId, 'turn.start', e.text, mentions))
    await update($, tree, list => [...withStart(list, 'turn.start'), turn])
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
    await addDraft($, toolDraft(e as unknown as Record<string, unknown>, ran, 'tool.call'), 'tool.call', e.agentId)
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
    const walk = (nodes: CtxNode[], depth: number, parentEvent?: string) => {
      for (const n of nodes) {
        const hasKids = n.children.length > 0
        const isOpen = open.has(n.id)
        const mark = hasKids ? (isOpen ? '▾ ' : '▸ ') : '  '
        const indent = '  '.repeat(depth)
        const view: CtxView | undefined = n.path
          ? { label: n.label, path: n.path, line: n.line, isCapture: n.isCapture }
          : undefined
        const room = Math.max(8, width - indent.length - 4)
        const text = `${mark}${n.label}`
        const label = text.length > room ? `${text.slice(0, room - 1)}…` : text
        // A child shows its event only when it differs from the event of its parent.
        const event = n.event !== parentEvent ? n.event : undefined
        const hint = [n.hint, event && `on: ${event}`].filter(Boolean).join(' · ')
        rows.push(
          <Box key={`row:${n.id}`} flexDirection="column">
            <Box flexDirection="row">
              <Text>{indent}</Text>
              <Button
                key={`n:${n.id}`}
                plain
                dimColor={!hasKids && !view}
                onPress={() => (hasKids ? toggle(n.id) : view ? openViewer($, view) : undefined)}
              >
                {label}
              </Button>
              {view && (
                <Button key={`o:${n.id}`} plain dimColor onPress={() => openInHerdr($, view)}>
                  {' ↗'}
                </Button>
              )}
            </Box>
            {hint && (
              <Text dimColor wrap="truncate-end">
                {`${indent}    ${hint}`}
              </Text>
            )}
          </Box>,
        )
        if (isOpen) walk(n.children, depth + 1, n.event)
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

const allIds = (list: CtxNode[]): string[] => list.flatMap(n => (n.children.length ? [n.id, ...allIds(n.children)] : []))
