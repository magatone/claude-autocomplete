import type { Register } from 'claude-code'
import { complete, makeIndex, makeTerms } from './complete'

export const register: Register = on => {
  let general: string[] | undefined
  let terms: string[] = []

  on('prompt.autocomplete', { token: /^[A-Za-z][A-Za-z']+$/ }, async ($, e, next) => {
    if (!general) {
      const data = `${$.plugin.root}/data`
      general = makeIndex(JSON.parse(await $.fs.read(`${data}/wordfreq-en-25000-log.json`)))
      const files = (await $.fs.list(`${data}/terms`)).filter(f => f.name.endsWith('.txt'))
      terms = makeTerms(await Promise.all(files.map(f => $.fs.read(`${data}/terms/${f.name}`))), general)
    }
    const below = await next(e)
    return { suggestions: [...below.suggestions, ...complete(general, e.token, terms).map(text => ({ text }))] }
  })
}
