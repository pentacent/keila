import { history } from "prosemirror-history"
import { EditorState, Plugin } from "prosemirror-state"
import { EditorView } from "prosemirror-view"
import { markdownParser } from "./markdown-parser"
import { schema } from "./markdown-schema"
import { markdownSerializer } from "./markdown-serializer"

import { baseKeymap } from "prosemirror-commands"
import { keymap } from "prosemirror-keymap"
import { inputRules } from "./input-rules"
import { buildKeymap } from "./keymap"
import { buildDefaultMenu } from "./menu"

const syncPlugin = new Plugin({
  props: {
    handleDOMEvents: {
      blur(view, _event) {
        view.dom.dispatchEvent(
          new CustomEvent("x-sync", {
            bubbles: true
          })
        )
      }
    }
  }
})

/** Class representing the ProseMirror Markdown editor used by Keila.
 *
 * This editor syncs its state on every change to the specified `source` textarea.
 * Syncing can also be triggered manually with the custom `x-sync` event.
 */
class MarkdownEditor {
  /**
   * Initializes a new `MarkdownEditor`
   * @param {HTMLElement} place - DOM node where editor will be inserted.
   * @param {HTMLElement} source - Textarea where initial state will be taken from and synced to.
   */
  constructor(place, source) {
    this.source = source
    this.place = place
    this.place.parentNode.addEventListener("x-sync", e => this.sync(e))
    this.view = new EditorView(place, {
      state: EditorState.create({
        doc: markdownParser.parse(source.value),
        plugins: [
          buildDefaultMenu(),
          keymap(buildKeymap(schema)),
          keymap(baseKeymap),
          history(),
          inputRules,
          syncPlugin
        ]
      }),
      handleDoubleClickOn(view, _pos, node) {
        if (node.type === schema.nodes.image) {
          view.dom.parentNode.parentNode.querySelector(`.wysiwyg--menu [data-action=img]`).dispatchEvent(
            new Event("mousedown")
          )
        }
      }
    })
  }

  get content() {
    return markdownSerializer.serialize(this.view.state.doc)
  }

  sync(e) {
    this.source.value = this.content

    if (!(e.detail && e.detail.skipDispatch)) {
      this.source.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  focus() {
    this.view.focus()
  }

  destroy() {
    this.place.parentNode.removeEventListener("x-sync")
    this.view.destroy()
  }
}

export { MarkdownEditor }
