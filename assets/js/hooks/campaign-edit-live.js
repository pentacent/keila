import BlockEditor from "../campaign-editors/block"
import { MarkdownEditor } from "../campaign-editors/markdown"
import MarkdownSimpleEditor from "../campaign-editors/markdown-simple"
import MjmlEditor from "../campaign-editors/mjml"

const putHtmlPreview = (el) => {
  const content = el.innerText
  if (!content) return

  const iframes = document.querySelectorAll(el.dataset.iframe)
  if (!iframes.length) return

  for (let i = 0; i < iframes.length; i++) {
    const iframe = iframes[i]
    const scrollX = iframe.contentWindow.scrollX
    const scrollY = iframe.contentWindow.scrollY
    const doc = iframe.contentDocument
    doc.open()
    doc.write(content)
    doc.close()
    iframe.contentWindow.scrollTo(scrollX, scrollY)
  }
}

const MarkdownSimpleEditorHook = {
  mounted() {
    new MarkdownSimpleEditor(this.el)
  }
}

const MarkdownEditorHook = {
  mounted() {
    const place = this.el.querySelector(".editor")
    const target = document.querySelector(this.el.dataset.target)
    new MarkdownEditor(place, target)
  }
}

const BlockEditorHook = {
  mounted() {
    const place = this.el.querySelector(".editor")
    const target = document.querySelector(this.el.dataset.target)
    new BlockEditor(place, target)
  }
}

const MjmlEditorHook = {
  mounted() {
    const place = this.el.querySelector(".editor")
    const target = document.querySelector(this.el.dataset.target)
    const toolbar = document.querySelector(this.el.dataset.toolbar)
    new MjmlEditor(place, target, { toolbar })
  }
}

// Reuses the MjmlEditor class but with HTML-only tag completion (no
// MJML elements). `keila-content` is included so HTML templates can
// declare content slots.
const HtmlEditorHook = {
  mounted() {
    const place = this.el.querySelector(".editor")
    const target = document.querySelector(this.el.dataset.target)
    const toolbar = document.querySelector(this.el.dataset.toolbar)
    new MjmlEditor(place, target, {
      toolbar,
      extraTags: {
        "keila-content": {
          attrs: { name: null },
          globalAttrs: false
        }
      }
    })
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

export {
  BlockEditorHook as BlockEditor,
  HtmlEditorHook as HtmlEditor,
  HtmlPreviewHook as HtmlPreview,
  MarkdownEditorHook as MarkdownEditor,
  MarkdownSimpleEditorHook as MarkdownSimpleEditor,
  MjmlEditorHook as MjmlEditor
}
