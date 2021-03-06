import { MarkdownEditor } from "../campaign-editor"

const putHtmlPreview = (el) => {
  const content = el.innerText
  if (!content) return

  const iframe = document.getElementById(el.dataset.iframe)
  if (!iframe) return

  const doc = iframe.contentDocument
  doc.open()
  doc.write(content)
  doc.close()
}

const MarkdownEditorHook = {
  mounted() {
    let place = this.el.querySelector(".editor")
    new MarkdownEditor(place, document.querySelector("#campaign_text_body"))
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

export { MarkdownEditorHook as MarkdownEditor, HtmlPreviewHook as HtmlPreview }
