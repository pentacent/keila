import { acceptCompletion, completionStatus } from "@codemirror/autocomplete"
import { indentLess, indentMore } from "@codemirror/commands"

export const indentAndAutocompleteWithTab = {
  key: "Tab",
  preventDefault: true,
  shift: indentLess,
  run: (e) => {
    if (!completionStatus(e.state)) return indentMore(e)
    return acceptCompletion(e)
  }
}

export const saveUpdates = (source) => {
  return EditorView.updateListener.of((e) => {
    if (e.docChanged) {
      source.value = e.state.doc.toString()
      source.dispatchEvent(new Event("change", { bubbles: true }))
    }
  })
}
