// Pure matching logic, kept apart from register.ts so it can be tested without the engine.

const WORD = /^[a-z]+(?:'[a-z]+)?$/

// rows come from wordfreq-en-25000-log.json, already sorted by frequency (most common first).
export function makeIndex(rows: [string, number][]): string[] {
  return rows.map(r => r[0]).filter(w => WORD.test(w))
}

// ponytail: linear scan over ~25k words per keystroke, fast enough; switch to a sorted array + binary search if it ever lags.
export function complete(words: readonly string[], token: string, limit = 5): string[] {
  if (token.length < 2 || !/^[A-Za-z][A-Za-z']*$/.test(token)) return []
  const lower = token.toLowerCase()
  const out: string[] = []
  for (const w of words) {
    if (w.length > lower.length && w.startsWith(lower)) out.push(w)
    if (out.length === limit) break
  }
  // Keep the case the person started with: "Recom" -> "Recommend", "RECOM" -> "RECOMMEND".
  if (token === token.toUpperCase()) return out.map(w => w.toUpperCase())
  if (token[0] === token[0].toUpperCase()) return out.map(w => w[0].toUpperCase() + w.slice(1))
  return out
}
