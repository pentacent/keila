/*
 * This file is part of Keila.
 *
 * Keila is free software. You can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * Keila is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 * PARTICULAR PURPOSE.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see https://www.gnu.org/licenses/agpl-3.0.html
 *
 * This file incorporates work covered by the following copyright and
 * permission notice:
 *
 * Copyright (c) 2014 Vitaly Puzrin, Alex Kocharin.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

// Parse link destination
//
"use strict"

import markdownIt from "markdown-it"
const { unescapeAll } = markdownIt().utils

module.exports = function parseLinkDestination(str, start, max) {
  var code,
    level,
    pos = start,
    result = {
      ok: false,
      isLiquid: false,
      pos: 0,
      lines: 0,
      str: ""
    }

  // Link is delimited by < and >
  if (str.charCodeAt(pos) === 0x3C /* < */) {
    pos++
    while (pos < max) {
      code = str.charCodeAt(pos)
      if (code === 0x0A /* \n */) return result
      if (code === 0x3C /* < */) return result
      if (code === 0x3E /* > */) {
        result.pos = pos + 1
        result.str = unescapeAll(str.slice(start + 1, pos))
        result.ok = true
        return result
      }
      if (code === 0x5C /* \ */ && pos + 1 < max) {
        pos += 2
        continue
      }

      pos++
    }

    // no closing '>'
    return result
  }

  // Link is a Liquid tag
  if (str.charCodeAt(pos) === 0x7B /* { */) {
    let closingChar
    let closing
    let startPos = pos
    pos++
    while (pos < max) {
      code = str.charCodeAt(pos)

      if (pos === startPos + 1) {
        if (code === 0x7B) {
          closingChar = 0x7D // {{
        } else if (code === 0x25) {
          closingChar = 0x25 // {%
        } else {
          return ""
        }
      } else if (!closing) {
        if (code === closingChar) {
          closing = true
          pos++
          continue
        }
      } else if (closing && code === 0x7D) {
        result.pos = pos + 1
        result.str = str.slice(start, pos + 1)
        result.ok = true
        result.isLiquid = true
        return result
      }
      pos++
    }

    // invalid Liquid tag
    return result
  }

  // this should be ... } else { ... branch
  level = 0
  while (pos < max) {
    code = str.charCodeAt(pos)

    if (code === 0x20) break

    // ascii control characters
    if (code < 0x20 || code === 0x7F) break

    if (code === 0x5C /* \ */ && pos + 1 < max) {
      if (str.charCodeAt(pos + 1) === 0x20) break
      pos += 2
      continue
    }

    if (code === 0x28 /* ( */) {
      level++
      if (level > 32) return result
    }

    if (code === 0x29 /* ) */) {
      if (level === 0) break
      level--
    }

    pos++
  }

  if (start === pos) return result
  if (level !== 0) return result

  result.str = unescapeAll(str.slice(start, pos))
  result.pos = pos
  result.ok = true
  return result
}
