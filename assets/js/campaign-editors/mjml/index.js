import { defaultKeymap } from "@codemirror/commands"
import { html } from "@codemirror/lang-html"
import { EditorState } from "@codemirror/state"
import { EditorView, keymap } from "@codemirror/view"
import { basicSetup } from "codemirror"

import { indentAndAutocompleteWithTab, saveUpdates } from "./helpers.js"
import tags from "./tags.js"
import theme from "./theme.js"

export default class MjmlEditor {
  constructor(place, source) {
    this.source = source
    this.place = place

    let state = EditorState.create({
      doc: source.value,
      extensions: [
        basicSetup,
        html({ extraTags: tags, selfClosingTags: true }),
        keymap.of([...defaultKeymap, indentAndAutocompleteWithTab]),
        theme,
        saveUpdates(source)
      ]
    })

    this.view = new EditorView({
      state: state,
      parent: place
    })

    place.parentNode.parentNode.addEventListener("x-show-image-dialog", () => {
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
