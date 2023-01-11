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

// Process [link](<to> "stuff")

"use strict"

import markdownIt from "markdown-it"
const { normalizeReference, isSpace } = markdownIt().utils
import parseLinkDestination from "./parse-link-destination"

const linkWithLiquid = function(state, silent) {
  var attrs,
    code,
    label,
    labelEnd,
    labelStart,
    pos,
    res,
    ref,
    token,
    href = "",
    title = "",
    oldPos = state.pos,
    max = state.posMax,
    start = state.pos,
    parseReference = true

  if (state.src.charCodeAt(state.pos) !== 0x5B /* [ */) return false

  labelStart = state.pos + 1
  labelEnd = state.md.helpers.parseLinkLabel(state, state.pos, true)

  // parser failed to find ']', so it's not a valid link
  if (labelEnd < 0) return false

  pos = labelEnd + 1
  if (pos < max && state.src.charCodeAt(pos) === 0x28 /* ( */) {
    //
    // Inline link
    //

    // might have found a valid shortcut link, disable reference parsing
    parseReference = false

    // [link](  <href>  "title"  )
    //        ^^ skipping these spaces
    pos++
    for (; pos < max; pos++) {
      code = state.src.charCodeAt(pos)
      if (!isSpace(code) && code !== 0x0A) {
        break
      }
    }
    if (pos >= max) return false

    // [link](  <href>  "title"  )
    //          ^^^^^^ parsing link destination
    start = pos
    res = parseLinkDestination(state.src, pos, state.posMax)
    if (res.ok) {
      href = res.isLiquid ? res.str : state.md.normalizeLink(res.str)
      if (res.isLiquid || state.md.validateLink(href)) {
        pos = res.pos
      } else {
        href = ""
      }

      // [link](  <href>  "title"  )
      //                ^^ skipping these spaces
      start = pos
      for (; pos < max; pos++) {
        code = state.src.charCodeAt(pos)
        if (!isSpace(code) && code !== 0x0A) break
      }

      // [link](  <href>  "title"  )
      //                  ^^^^^^^ parsing link title
      res = state.md.helpers.parseLinkTitle(state.src, pos, state.posMax)
      if (pos < max && start !== pos && res.ok) {
        title = res.str
        pos = res.pos

        // [link](  <href>  "title"  )
        //                         ^^ skipping these spaces
        for (; pos < max; pos++) {
          code = state.src.charCodeAt(pos)
          if (!isSpace(code) && code !== 0x0A) break
        }
      }
    }

    if (pos >= max || state.src.charCodeAt(pos) !== 0x29 /* ) */) {
      // parsing a valid shortcut link failed, fallback to reference
      parseReference = true
    }
    pos++
  }

  if (parseReference) {
    //
    // Link reference
    //
    if (typeof state.env.references === "undefined") return false

    if (pos < max && state.src.charCodeAt(pos) === 0x5B /* [ */) {
      start = pos + 1
      pos = state.md.helpers.parseLinkLabel(state, pos)
      if (pos >= 0) {
        label = state.src.slice(start, pos++)
      } else {
        pos = labelEnd + 1
      }
    } else {
      pos = labelEnd + 1
    }

    // covers label === '' and label === undefined
    // (collapsed reference link and shortcut reference link respectively)
    if (!label) label = state.src.slice(labelStart, labelEnd)

    ref = state.env.references[normalizeReference(label)]
    if (!ref) {
      state.pos = oldPos
      return false
    }
    href = ref.href
    title = ref.title
  }

  //
  // We found the end of the link, and know for a fact it's a valid link;
  // so all that's left to do is to call tokenizer.
  //
  if (!silent) {
    state.pos = labelStart
    state.posMax = labelEnd

    token = state.push("link_open", "a", 1)
    token.attrs = attrs = [["href", href]]
    if (title) {
      attrs.push(["title", title])
    }

    state.linkLevel++
    state.md.inline.tokenize(state)
    state.linkLevel--

    token = state.push("link_close", "a", -1)
  }

  state.pos = pos
  state.posMax = max
  return true
}

export const markdownItLinkWithLiquid = (md) => {
  md.inline.ruler.at("link", linkWithLiquid)
  return md
}
