import { defaultMarkdownSerializer } from "prosemirror-markdown"

const markdownSerializer = defaultMarkdownSerializer
markdownSerializer.marks.liquid = { open: "", close: "", mixable: false, escape: false }

markdownSerializer.nodes.image = (state, node) => {
  state.write(
    "![" + state.esc(node.attrs.alt || "") + "](" + node.attrs.src.replace(/[\(\)]/g, "\\$&")
      + (node.attrs.title ? " \"" + node.attrs.title.replace(/"/g, "\\\"") + "\"" : "") + ")"
  )
  if (node.attrs.width) {
    state.write("{: width=" + node.attrs.width + "}")
  }
}

export { markdownSerializer }
