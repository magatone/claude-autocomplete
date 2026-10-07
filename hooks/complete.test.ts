import { expect, test } from 'claude-code/testing'
import { complete, makeIndex } from './complete'

const words = makeIndex([['the', -2], ['recommend', -9], ['don\'t', -9], ['record', -9], ['recommendation', -10], ['re-do', -12], ['123', -12]])

test('suggests words by prefix, most frequent first', () => {
  expect(complete(words, 'rec')).toEqual(['recommend', 'record', 'recommendation'])
})

test('keeps the case the person typed', () => {
  expect(complete(words, 'Recom')).toEqual(['Recommend', 'Recommendation'])
  expect(complete(words, 'RECOM')).toEqual(['RECOMMEND', 'RECOMMENDATION'])
})

test('skips short, non-word and already-complete tokens', () => {
  expect(complete(words, 'r')).toEqual([])
  expect(complete(words, '/re')).toEqual([])
  expect(complete(words, 'the')).toEqual([])
  expect(words).not.toContain('re-do')
  expect(words).toContain("don't")
})
