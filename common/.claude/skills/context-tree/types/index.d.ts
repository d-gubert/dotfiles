export type CtxNode = {
  id: string
  label: string
  /** Dim text after the label: tokens, a tier, an error mark. */
  hint?: string
  /** The file the viewer and nvim open. */
  path?: string
  line?: number
  /** True when `path` is a capture the mod wrote, not a file of the project. */
  isCapture?: boolean
  /** The hook event that added the node; the pane shows it as an `on:` child row. */
  event?: string
  children: CtxNode[]
}

export type CtxView = { label: string; path: string; line?: number; isCapture?: boolean }

export type CtxUsage = { percent?: number; tokens?: number; window: number }

declare module 'claude-code' {
  interface PluginState {
    'context-tree': {
      tree: CtxNode[]
      expanded: string[]
      viewing: CtxView | null
      pending: CtxNode[]
      usage: CtxUsage | null
    }
  }
}
