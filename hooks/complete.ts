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
  return matchCase(token, [...tech, ...matches(general, lower, limit - tech.length, seen)])
}

// Keep the case the person started with: "Recom" -> "Recommend", "RECOM" -> "RECOMMEND".
// Proper names ("TypeScript") keep their own case unless the person types in all caps.
function matchCase(token: string, out: string[]): string[] {
  if (token === token.toUpperCase()) return out.map(w => w.toUpperCase())
  if (token.charAt(0) === token.charAt(0).toUpperCase()) return out.map(w => w.charAt(0).toUpperCase() + w.slice(1))
  return out
}

// Every known word once, work terms first (in their own case), then everyday English: the order typo fixes are offered in.
export function makeTypoPool(general: readonly string[], terms: readonly string[]): string[] {
  const byKey = new Map<string, string>()
  for (const w of [...terms, ...general]) if (!byKey.has(w.toLowerCase())) byKey.set(w.toLowerCase(), w)
  return [...byKey.values()]
}

// Fewest single-letter edits (add, drop, change, or swap two neighbours) between a and b, or max + 1 once it is past max.
function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1
  let before: number[] = []
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j)
  for (let i = 1; i <= a.length; i++) {
    const cur = [i]
    let best = i
    for (let j = 1; j <= b.length; j++) {
      let v = Math.min(prev[j]! + 1, cur[j - 1]! + 1, prev[j - 1]! + (a[i - 1] === b[j - 1] ? 0 : 1))
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) v = Math.min(v, before[j - 2]! + 1)
      cur[j] = v
      best = Math.min(best, v)
    }
    if (best > max) return max + 1
    before = prev
    prev = cur
  }
  return prev[b.length]!
}

// "Did you mean" for a misspelt word, used only when nothing matches exactly.
// The person is mid-word, so the typed text is compared with the start of each word (cut one letter shorter,
// the same length, or one longer). One slip at most, the first letter taken as right, 4+ letters, and nothing
// when the typed text is already a known word. Measured on 60 common typos: 58 caught, none shown while typing correctly.
// ponytail: scans the whole pool per keystroke (~0.4 ms); index by first letter if it ever lags.
export function fixTypos(pool: readonly string[], known: ReadonlySet<string>, token: string, limit = 5): string[] {
  const lower = token.toLowerCase()
  if (token.length < 4 || !/^[A-Za-z]+$/.test(token) || known.has(lower)) return []
  const out: string[] = []
  for (const w of pool) {
    if (out.length === limit) break
    const key = w.toLowerCase()
    if (key[0] !== lower[0] || key === lower) continue
    const cuts = [lower.length - 1, lower.length, lower.length + 1].filter(n => n > 0 && n <= key.length)
    if (cuts.some(n => editDistance(lower, key.slice(0, n), 1) <= 1)) out.push(w)
  }
  return matchCase(token, out)
}
