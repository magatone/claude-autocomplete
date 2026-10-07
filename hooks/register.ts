import type { Register } from 'claude-code'
import { complete, makeIndex } from './complete'

export const register: Register = on => {
  let words: string[] | undefined

  on('prompt.autocomplete', { token: /^[A-Za-z][A-Za-z']+$/ }, async ($, e, next) => {
    words ??= makeIndex(JSON.parse(await $.fs.read(`${$.plugin.root}/data/wordfreq-en-25000-log.json`)))
    const below = await next(e)
    return { suggestions: [...below.suggestions, ...complete(words, e.token).map(text => ({ text }))] }
  })
}
