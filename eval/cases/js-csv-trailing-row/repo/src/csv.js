'use strict'

/**
 * Parse a CSV document into rows of raw field strings.
 * No quoting support: fields are split on commas, lines on newlines.
 *
 * @param {string} text
 * @returns {string[][]}
 */
function parseRows(text) {
  const lines = text.split('\n')
  const rows = []
  for (const line of lines) {
    const row = line.split(',')
    if (row.length > 0) rows.push(row)
  }
  return rows
}

module.exports = { parseRows }
