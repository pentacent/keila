import { Decoration, ViewPlugin } from "@codemirror/view"

const tagMark = Decoration.mark({ class: "cm-keila-content" })
const blockMark = Decoration.mark({ class: "cm-keila-content-block" })

const blockRegex = /<keila-content\b[^>]*>[\s\S]*?<\/keila-content>/g

function buildDecorations(view) {
  const text = view.state.doc.toString()
  const decos = []

  let match
  while ((match = blockRegex.exec(text)) !== null) {
    const start = match.index
    const end = start + match[0].length

    // Background over the whole block.
    decos.push(blockMark.range(start, end))

    // Accent on the opening tag.
    const open = match[0].match(/^<keila-content\b[^>]*>/)
    if (open) decos.push(tagMark.range(start, start + open[0].length))

    // Accent on the closing tag.
    const close = "</keila-content>"
    if (match[0].endsWith(close)) {
      decos.push(tagMark.range(end - close.length, end))
    }
  }

  return Decoration.set(decos, true)
}

export const keilaContentHighlight = ViewPlugin.fromClass(
  class {
    constructor(view) {
      this.decorations = buildDecorations(view)
    }

    update(update) {
      if (update.docChanged || update.viewportChanged) {
        this.decorations = buildDecorations(update.view)
      }
    }
  },
  {
    decorations: v => v.decorations
  }
)
