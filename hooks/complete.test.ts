import { expect, test } from 'claude-code/testing'
import { complete, makeIndex, makeTerms } from './complete'

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

const general = makeIndex([['community', -5], ['common', -5], ['committee', -6], ['commission', -6], ['comments', -6], ['commit', -9], ['type', -5]])
const terms = makeTerms(['# role list\ncommit\ncommits\nrefactor\ntypescript\n', 'TypeScript\ncommand\n'], general)

test('work terms come first, everyday words fill the rest', () => {
  expect(complete(general, 'comm', terms)).toEqual(['commit', 'commits', 'command', 'community', 'common'])
})

test('terms the general list knows are ordered by its frequency, duplicates merged', () => {
  expect(terms[0]).toBe('commit')
  expect(terms.filter(t => t.toLowerCase() === 'typescript')).toEqual(['TypeScript'])
})

test('proper names keep their case', () => {
  expect(complete(general, 'types', terms)).toEqual(['TypeScript'])
})

test('short tokens let only one work term lead', () => {
  expect(complete(general, 'com', terms)).toEqual(['commit', 'community', 'common', 'committee', 'commission'])
})
