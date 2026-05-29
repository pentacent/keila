import { defaultKeymap } from "@codemirror/commands"
import { html } from "@codemirror/lang-html"
import { EditorState } from "@codemirror/state"
import { EditorView, keymap } from "@codemirror/view"
import { basicSetup } from "codemirror"

import { indentAndAutocompleteWithTab, saveUpdates } from "./helpers.js"
import { keilaContentHighlight } from "./keila_content_highlight.js"
import tags from "./tags.js"
import theme from "./theme.js"

export default class MjmlEditor {
  static activeEditor = null

  constructor(place, source, options = {}) {
    this.source = source
    this.place = place
    const extraTags = options.extraTags ?? tags

    let state = EditorState.create({
      doc: source.value,
      extensions: [
        basicSetup,
        html({ extraTags, selfClosingTags: true }),
        keymap.of([...defaultKeymap, indentAndAutocompleteWithTab]),
        theme,
        keilaContentHighlight,
        saveUpdates(source)
      ]
    })

    this.view = new EditorView({
      state: state,
      parent: place
    })

    if (!MjmlEditor.activeEditor) MjmlEditor.activeEditor = this
    this.view.dom.addEventListener("focusin", () => {
      MjmlEditor.activeEditor = this
    })

    document.getElementById("mjml-editor-toolbar").addEventListener("x-show-image-dialog", () => {
      if (MjmlEditor.activeEditor !== this) return
      document
        .querySelector("[data-dialog-for=image]")
        .dispatchEvent(new CustomEvent("x-show", { detail: {} }))
      window.addEventListener(
        "update-image",
        (e) => {
          const { src } = e.detail
          if (!src) {
            this.view.focus()
            return
          }
          this.view.dispatch(this.view.state.replaceSelection(src))
        },
        { once: true }
      )
    })
  }
}
