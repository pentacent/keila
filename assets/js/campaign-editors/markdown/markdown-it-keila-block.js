// This function checks for the presence of a Liquid opening tag and returns the
// first character of the closing tag ("%" or "}")
const getBlockInfo = (state, start) => {
  // {
  if (state.src.charCodeAt(start) === 0x3A) {
    const match = state.src.slice(start).match(/^:keila(?::[a-z0-9]+)+:/)
    if (!match) return
    const parts = match[0].split(":")
    if (parts[1] === "col") {
      const cols = parseInt(parts[2])
      return { type: "col", cols: cols }
    }
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

function keilaBlock(state, silent) {
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

export const markdownItKeilaBlock = (md) => {
  md.inline.ruler.after("emphasis", "keila-block", keilaBlock)
}
