'use strict'
const test = require('node:test')
const assert = require('node:assert')
const { parseRows } = require('../src/csv.js')

test('no trailing newline yields the same rows', () => {
  assert.deepStrictEqual(parseRows('a,b\n1,2'), [['a', 'b'], ['1', '2']])
})

test('trailing newline does not create a phantom row', () => {
  assert.deepStrictEqual(parseRows('a,b\n1,2\n'), [['a', 'b'], ['1', '2']])
})

test('single column', () => {
  assert.deepStrictEqual(parseRows('a\nb\n'), [['a'], ['b']])
})

test('preserves empty interior fields', () => {
  assert.deepStrictEqual(parseRows('a,,c\n'), [['a', '', 'c']])
})
