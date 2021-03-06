import { EditorView } from "prosemirror-view"
import { EditorState, Plugin } from "prosemirror-state"
import { schema, defaultMarkdownParser, defaultMarkdownSerializer } from "prosemirror-markdown"
import { history } from "prosemirror-history"

import { keymap } from "prosemirror-keymap"
import { baseKeymap } from "prosemirror-commands"
import { buildKeymap } from "./keymap"
import { buildDefaultMenu } from "./menu"


const syncPlugin = new Plugin({
    view(editorView) {
        return {
            update() {
                editorView.dom.dispatchEvent(new CustomEvent("x-sync", {
                    bubbles: true,
                    detail: { skipDispatch: true }
                }))
            }
        }
    }
})

/** Class representing the ProseMirror Markdoen editor used by Keila.
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
                doc: defaultMarkdownParser.parse(source.value),
                plugins: [
                    buildDefaultMenu(),
                    keymap(buildKeymap(schema)),
                    keymap(baseKeymap),
                    history(),
                    syncPlugin
                ]
            })
        })
    }

    get content() {
        return defaultMarkdownSerializer.serialize(this.view.state.doc)
    }

    sync(e) {
        this.source.value = this.content

        if (!e.detail.skipDispatch) {
            this.source.dispatchEvent(new Event("change", { bubbles: true }))
        }
    }

    focus() { this.view.focus() }

    destroy() {
        this.place.parentNode.removeEventListener("x-sync")
        this.view.destroy()
    }
}

export { MarkdownEditor }
