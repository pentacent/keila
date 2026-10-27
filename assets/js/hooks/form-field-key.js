import { transliterate } from "transliteration"

const labelToKey = (label) =>
  transliterate(label.replace(/['’ʼ]/g, ""))
    .replace(/[^a-zA-Z0-9]+/g, "_")
    .replace(/^[0-9_]+|_+$/g, "")
    .toLowerCase()

/**
 * This hook is used on custom form fields in the form editor.
 *
 * It derives the data key from the label until the key has been edited or saved.
 */
export const FormFieldKey = {
  mounted() {
    this.keyEdited = false
    this.defaultKey = this.keyInput().value
    this.defaultLabel = this.labelInput().value
    this.el.addEventListener("input", (e) => this.handleInput(e.target))
    this.maybeShowKeyEditor()
  },

  // A patch can reset the key input to an older key from the server while the
  // latest label change is still debounced, so the key is derived again.
  updated() {
    this.maybeDeriveKey()
    this.maybeShowKeyEditor()
  },

  handleInput(input) {
    const { role } = input.dataset

    if (role === "key") {
      this.keyEdited = true
      return
    }

    if (role === "label") this.maybeDeriveKey()
  },

  maybeDeriveKey() {
    if (this.keyEdited || this.el.hasAttribute("data-saved")) return

    const label = this.labelInput().value
    this.keyInput().value = label === this.defaultLabel ? this.defaultKey : labelToKey(label) || this.defaultKey
  },

  maybeShowKeyEditor() {
    if (!this.el.hasAttribute("data-key-error")) return

    this.js().removeClass(this.keyEditor(), "hidden")
    this.js().addClass(this.keyHint(), "hidden")
  },

  labelInput() {
    return this.el.querySelector("[data-role=label]")
  },

  keyInput() {
    return this.el.querySelector("[data-role=key]")
  },

  keyEditor() {
    return this.el.querySelector("[data-role=key-editor]")
  },

  keyHint() {
    return this.el.querySelector("[data-role=key-hint]")
  }
}
