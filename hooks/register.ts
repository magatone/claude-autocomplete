import type { Register } from 'claude-code'
import { complete, fixTypos, makeIndex, makeTerms, makeTypoPool } from './complete'
import { applyShortcut, matchShortcuts, runShortcutCommand, type Shortcuts } from './shortcuts'

const STORE_KEY = 'shortcuts'
// The model calls the tool as mcp__<plugin name>__<tool name>.
const TOOL = 'mcp__english-autocomplete__shortcuts'

const asShortcuts = (value: unknown): Shortcuts => (value && typeof value === 'object' ? (value as Shortcuts) : {})

export const register: Register = on => {
  let general: string[] | undefined
  let terms: string[] = []
  let pool: string[] = []
  let known = new Set<string>()
  // Cached copy of what $.store holds; the engine wants $.store spelled out at each call, hence no helper.
  let shortcuts: Shortcuts | undefined

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'shortcut',
      description: 'Prompt-box shortcuts: /shortcut add ptg push to github | remove ptg | list',
    })
    await $.tool.register({
      name: 'shortcuts',
      description:
        "Manage the person's prompt-box shortcuts (english-autocomplete plugin). A shortcut is a short key " +
        'like "ptg" that the person turns into a phrase like "push to github" by pressing Tab. ' +
        'Use when the person asks to add, change, remove or list shortcuts.',
      inputSchema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['add', 'remove', 'list'] },
          key: { type: 'string', description: 'The short key: 2+ letters or digits starting with a letter, e.g. "ptg"' },
          text: { type: 'string', description: 'For add: the phrase the key turns into' },
        },
        required: ['action'],
      },
    })
    return next(e)
  })

  on('command.run', { command: 'shortcut' }, async ($, e) => {
    shortcuts ??= asShortcuts(await $.store.get(STORE_KEY))
    const { map, message } = runShortcutCommand(shortcuts, e.args)
    if (map !== shortcuts) await $.store.set(STORE_KEY, (shortcuts = map))
    return { text: message }
  })

  // ponytail: no matcher, since this build's tool-name types don't list a plugin's own tool; one string compare per call.
  on('tool.call', async ($, e, next) => {
    if ((e.tool as string) !== TOOL) return next(e)
    const input = e as unknown as Record<string, unknown>
    shortcuts ??= asShortcuts(await $.store.get(STORE_KEY))
    const { map, message } = applyShortcut(shortcuts, String(input.action ?? ''), String(input.key ?? ''), String(input.text ?? ''))
    if (map !== shortcuts) await $.store.set(STORE_KEY, (shortcuts = map))
    return { result: message }
  }).catch(($, e, next) => next(e)) // a failure here must never block the person's other tools

  on('prompt.autocomplete', { token: /^[A-Za-z][A-Za-z0-9']+$/ }, async ($, e, next) => {
    if (!general) {
      const data = `${$.plugin.root}/data`
      general = makeIndex(JSON.parse(await $.fs.read(`${data}/wordfreq-en-25000-log.json`)))
      const files = (await $.fs.list(`${data}/terms`)).filter(f => f.name.endsWith('.txt'))
      terms = makeTerms(await Promise.all(files.map(f => $.fs.read(`${data}/terms/${f.name}`))), general)
      pool = makeTypoPool(general, terms)
      known = new Set(pool.map(w => w.toLowerCase()))
    }
    shortcuts ??= asShortcuts(await $.store.get(STORE_KEY))
    // Shortcuts lead, then words; five rows in all. Only when nothing matches do typo fixes fill in, marked as guesses.
    const exact = [...matchShortcuts(shortcuts, e.token), ...complete(general, e.token, terms)].slice(0, 5)
    const mine = exact.length
      ? exact.map(text => ({ text }))
      : fixTypos(pool, known, e.token).map(text => ({ text, description: 'typo?' }))
    const below = await next(e)
    return { suggestions: [...below.suggestions, ...mine] }
  })
}
