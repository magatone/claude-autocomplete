import { expect, test } from 'claude-code/testing'
import { applyShortcut, matchShortcuts, runShortcutCommand } from './shortcuts'

test('/shortcut add, list and remove', () => {
  let r = runShortcutCommand({}, 'add ptg push to github')
  expect(r.map).toEqual({ ptg: 'push to github' })
  expect(r.message).toBe('Added ptg -> push to github')
  r = runShortcutCommand(r.map, 'add PTG push it to GitHub')
  expect(r.map).toEqual({ ptg: 'push it to GitHub' })
  expect(runShortcutCommand(r.map, 'list').message).toBe('ptg -> push it to GitHub')
  expect(runShortcutCommand(r.map, 'remove ptg').map).toEqual({})
  expect(runShortcutCommand({}, '').message).toContain('No shortcuts yet')
})

test('bad input changes nothing', () => {
  const map = { ptg: 'push to github' }
  expect(applyShortcut(map, 'add', 'p', 'x').map).toBe(map)
  expect(applyShortcut(map, 'add', '1ab', 'x').map).toBe(map)
  expect(applyShortcut(map, 'add', 'ok', '  ').map).toBe(map)
  expect(applyShortcut(map, 'remove', 'nope').map).toBe(map)
  expect(applyShortcut(map, 'explode').message).toContain('Usage')
})

test('typed key shows its phrase, exact match first', () => {
  const map = { ptg: 'push to github', pt: 'please test', prr: 'please review' }
  expect(matchShortcuts(map, 'pt')).toEqual(['please test', 'push to github'])
  expect(matchShortcuts(map, 'PTG')).toEqual(['push to github'])
  expect(matchShortcuts(map, 'zz')).toEqual([])
})
