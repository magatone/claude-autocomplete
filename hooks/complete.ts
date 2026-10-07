// Pure matching logic, kept apart from register.ts so it can be tested without the engine.

const WORD = /^[a-z]+(?:'[a-z]+)?$/

// rows come from wordfreq-en-25000-log.json, already sorted by frequency (most common first).
export function makeIndex(rows: [string, number][]): string[] {
  return rows.map(r => r[0]).filter(w => WORD.test(w))
}

// Parses the data/terms/*.txt files (one word per line, # comments) into one list:
// words the general list knows come first in its frequency order, the rest in file order.
// A proper name ("TypeScript") wins over the same word in lowercase.
export function makeTerms(texts: readonly string[], general: readonly string[]): string[] {
  const byKey = new Map<string, string>()
  for (const line of texts.flatMap(t => t.split(/\r?\n/))) {
    const w = line.trim()
    if (!w || w.startsWith('#')) continue
    const key = w.toLowerCase()
    if (!byKey.has(key) || w !== key) byKey.set(key, w)
  }
  const rank = new Map(general.map((w, i) => [w, i]))
  const order = [...byKey.keys()]
  return order
    .map((key, i) => ({ word: byKey.get(key)!, at: rank.get(key) ?? general.length + i }))
    .sort((a, b) => a.at - b.at)
    .map(t => t.word)
}

function matches(words: readonly string[], lower: string, limit: number, skip: Set<string>): string[] {
  const out: string[] = []
  for (const w of words) {
    if (out.length === limit) break
    const key = w.toLowerCase()
    if (key.length > lower.length && key.startsWith(lower) && !skip.has(key)) out.push(w), skip.add(key)
  }
  return out
}

// ponytail: linear scan over ~25k words per keystroke, fast enough; switch to a sorted array + binary search if it ever lags.
// Up to 3 work terms come first so "comm" shows "commit" before "community"; the rest is everyday English.
// With 3 letters or fewer only 1 work term leads, so "the" still offers "they", "their", "there".
export function complete(general: readonly string[], token: string, terms: readonly string[] = [], limit = 5): string[] {
  if (token.length < 2 || !/^[A-Za-z][A-Za-z']*$/.test(token)) return []
  const lower = token.toLowerCase()
  const seen = new Set<string>()
  const tech = matches(terms, lower, Math.min(token.length <= 3 ? 1 : 3, limit), seen)
  const out = [...tech, ...matches(general, lower, limit - tech.length, seen)]
  // Keep the case the person started with: "Recom" -> "Recommend", "RECOM" -> "RECOMMEND".
  // Proper names ("TypeScript") keep their own case unless the person types in all caps.
  if (token === token.toUpperCase()) return out.map(w => w.toUpperCase())
  if (token.charAt(0) === token.charAt(0).toUpperCase()) return out.map(w => w.charAt(0).toUpperCase() + w.slice(1))
  return out
}
