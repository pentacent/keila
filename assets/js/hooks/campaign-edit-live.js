import BlockEditor from "../campaign-editors/block"
import { MarkdownEditor } from "../campaign-editors/markdown"

const putHtmlPreview = (el) => {
  const content = el.innerText
  if (!content) return

  const iframe = document.getElementById(el.dataset.iframe)
  if (!iframe) return

  const scrollX = iframe.contentWindow.scrollX
  const scrollY = iframe.contentWindow.scrollY
  const doc = iframe.contentDocument
  doc.open()
  doc.write(content)
  doc.close()
  iframe.contentWindow.scrollTo(scrollX, scrollY)
}

const MarkdownEditorHook = {
  mounted() {
    let place = this.el.querySelector(".editor")
    new MarkdownEditor(place, document.querySelector("#campaign_text_body"))
  }
}

const BlockEditorHook = {
  mounted() {
    let place = this.el.querySelector(".editor")
    new BlockEditor(place, document.querySelector("#campaign_json_body"))
  }
}

const HtmlPreviewHook = {
  mounted() {
    putHtmlPreview(this.el)
  },
  updated() {
    putHtmlPreview(this.el)
  }
}

export { BlockEditorHook as BlockEditor, HtmlPreviewHook as HtmlPreview, MarkdownEditorHook as MarkdownEditor }
