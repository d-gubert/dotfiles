import type { CtxNode, CtxUsage, CtxView } from '../types'
import { tokens } from './tree'

// What the panes show, as plain values. register.tsx turns them into elements,
// because only a hook holds the element table of the surface.

export const PANE = 'context-tree'
export const VIEW = 'context-view'
export const VIEW_LIMIT = 100_000

/** One line of the tree pane. */
export type PaneRow = {
  id: string
  indent: string
  label: string
  /** The dim line under the label: the hint, and the event when it differs from the event of the parent. */
  hint: string
  hasKids: boolean
  /** The file a press opens; nothing for a node without one. */
  view?: CtxView
}

/** The lines of the tree pane: each node, and the children of each open node. */
export const paneRows = (list: CtxNode[], open: Set<string>, width: number): PaneRow[] => {
  const rows: PaneRow[] = []
  const walk = (nodes: CtxNode[], depth: number, parentEvent?: string) => {
    for (const n of nodes) {
      const hasKids = n.children.length > 0
      const isOpen = open.has(n.id)
      const mark = hasKids ? (isOpen ? '▾ ' : '▸ ') : '  '
      const indent = '  '.repeat(depth)
      const room = Math.max(8, width - indent.length - 4)
      const text = `${mark}${n.label}`
      const label = text.length > room ? `${text.slice(0, room - 1)}…` : text
      // A child shows its event only when it differs from the event of its parent.
      const event = n.event !== parentEvent ? n.event : undefined
      const hint = [n.hint, event && `on: ${event}`].filter(Boolean).join(' · ')
      const view = n.path ? { label: n.label, path: n.path, line: n.line, isCapture: n.isCapture } : undefined
      rows.push({ id: n.id, indent, label, hint, hasKids, view })
      if (isOpen) walk(n.children, depth + 1, n.event)
    }
  }
  walk(list, 0)
  return rows
}

/** The ids of every node that has children. */
export const allIds = (list: CtxNode[]): string[] =>
  list.flatMap(n => (n.children.length ? [n.id, ...allIds(n.children)] : []))

/** The ids with `id` added, or removed when they hold it. */
export const toggled = (ids: string[], id: string) => (ids.includes(id) ? ids.filter(x => x !== id) : [...ids, id])

/** The fill of the context window, for the head of the tree pane. */
export const usageText = (now: CtxUsage | null) =>
  now ? `${now.percent ?? '?'}% · ${now.tokens ? tokens(now.tokens) : '?'} of ${tokens(now.window)}` : 'no usage yet'

const LANGS: Record<string, string> = {
  ts: 'typescript', tsx: 'tsx', js: 'javascript', json: 'json', md: 'markdown', sh: 'bash',
  py: 'python', go: 'go', rs: 'rust', lua: 'lua', toml: 'toml', yaml: 'yaml', yml: 'yaml',
}

/** The language the viewer highlights a file in, by its extension. */
export const languageOf = (path: string) => LANGS[path.split('.').pop() ?? '']

const shellQuote = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`

/** The command a herdr pane runs to open the file in nvim; a capture opens read-only. */
export const nvimCommand = (view: CtxView) => {
  const args = [view.isCapture ? '-R' : '', view.line ? `+${view.line}` : '', shellQuote(view.path)]
  return `exec nvim ${args.filter(Boolean).join(' ')}`
}

/** The id of the pane that `herdr pane split` printed, or nothing. */
export const splitPaneId = (stdout: string): string | undefined => {
  try {
    const id: unknown = JSON.parse(stdout)?.result?.pane?.pane_id
    return typeof id === 'string' ? id : undefined
  } catch {
    return undefined
  }
}
