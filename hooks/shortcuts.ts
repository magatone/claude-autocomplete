// Shortcuts: a short key ("ptg") the person turns into a phrase ("push to github") with Tab.
// Pure logic only; register.ts keeps the map in $.store and wires the /shortcut command and the model's tool.

export type Shortcuts = Record<string, string>

const KEY = /^[A-Za-z][A-Za-z0-9]+$/

// Returns an error message, or undefined when the pair can be saved.
export function checkShortcut(key: string, text: string): string | undefined {
  if (!KEY.test(key)) return `"${key}" can't be a shortcut: use 2+ letters or digits, starting with a letter (e.g. ptg).`
  if (!text.trim()) return `Give the text "${key}" should turn into.`
  if (text.length > 500) return 'Keep the text under 500 characters.'
}

// Shortcut phrases whose key starts with what is typed; an exact key comes first.
export function matchShortcuts(map: Shortcuts, token: string): string[] {
  const lower = token.toLowerCase()
  return Object.keys(map)
    .filter(k => k.startsWith(lower))
    .sort((a, b) => Number(b === lower) - Number(a === lower) || a.localeCompare(b))
    .map(k => map[k] as string)
}

export function listShortcuts(map: Shortcuts): string {
  const keys = Object.keys(map).sort()
  if (keys.length === 0) return 'No shortcuts yet. Add one with: /shortcut add ptg push to github'
  return keys.map(k => `${k} -> ${map[k]}`).join('\n')
}

// One change to the map: what the /shortcut command and the model's tool both call.
export function applyShortcut(map: Shortcuts, action: string, key = '', text = ''): { map: Shortcuts; message: string } {
  const k = key.trim().toLowerCase()
  const phrase = text.trim()
  if (action === 'list') return { map, message: listShortcuts(map) }
  if (action === 'add') {
    const error = checkShortcut(k, phrase)
    if (error) return { map, message: error }
    const was = map[k]
    return { map: { ...map, [k]: phrase }, message: was ? `Updated ${k}: ${was} -> ${phrase}` : `Added ${k} -> ${phrase}` }
  }
  if (action === 'remove') {
    if (!(k in map)) return { map, message: `No shortcut named "${k}".` }
    const rest = { ...map }
    delete rest[k]
    return { map: rest, message: `Removed ${k}.` }
  }
  return { map, message: 'Usage: /shortcut add <key> <text> | /shortcut remove <key> | /shortcut list' }
}

// "/shortcut add ptg push to github" -> applyShortcut(map, 'add', 'ptg', 'push to github')
export function runShortcutCommand(map: Shortcuts, args: string): { map: Shortcuts; message: string } {
  const [action = 'list', key = '', ...rest] = args.trim().split(/\s+/).filter(Boolean)
  return applyShortcut(map, action.toLowerCase(), key, rest.join(' '))
}
