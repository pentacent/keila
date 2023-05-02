// This function checks for the presence of a Liquid opening tag and returns the
// first character of the closing tag ("%" or "}")
const getLiquidClosingChar = (state, start) => {
  // {
  if (state.src.charCodeAt(start) === 0x7B) {
    // {{
    if (state.src.charCodeAt(start + 1) === 0x7B) return 0x7D

    // {%
    if (state.src.charCodeAt(start + 1) === 0x25) return 0x25
  }
}

// This function checks for the presence of Liquid closing tags
const findLiquidClosingTag = (state, start, max, closingChar) => {
  state.pos = start + 2 // skip opening tag

  while (state.pos < max) {
    if (state.src.charCodeAt(state.pos) === closingChar && state.src.charCodeAt(state.pos + 1) == 0x7D) {
      state.md.inline.skipToken(state)
      return true
    }

    state.md.inline.skipToken(state)
  }
}

function liquid(state, silent) {
  const start = state.pos,
    max = state.posMax

  const closingChar = getLiquidClosingChar(state, start)
  if (!closingChar) return false
  if (silent) return false
  if (start + 3 >= max) return false

  if (!findLiquidClosingTag(state, start, max, closingChar)) {
    state.pos = start
    return false
  }

  const content = state.src.slice(start, state.pos + 1)
  state.posMax = state.pos
  state.pos = start + 1

  state.push("liquid_open", "liquid", 1)

  const contentToken = state.push("text", "", 0)
  contentToken.content = content

  state.push("liquid_close", "liquid", -2)

  state.pos = state.posMax + 1
  state.posMax = max
  return true
}

export const markdownItLiquid = (md) => {
  md.inline.ruler.after("emphasis", "liquid", liquid)
}
