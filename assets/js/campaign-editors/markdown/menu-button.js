import { toggleClass } from "./helpers"

/** Class for handling editor buttons. */
export class MenuButton {
  /**
   * Initialize a new editor button.
   * @param {Object} opts - options for configuring the MenuButton.
   * @param {function} opts.dom - callback function to find the button dom element within the editor dom.
   * @param {function} [opts.isActive] - callback function that takes editor state and returns whether button is currently in an active state.
   * @param {function} [opts.isEnabled] - callback function that takes editor state and returns whether button can currently be used.
   * @param {function} [opts.isVisible] - callback function that takes editor state and returns whether button should currently be visible or hidden.
   * @param {function} [opts.command] - ProseMirror command to dispatch on button click
   * @param {function} [opts.exec] - Callback function that takes editor state and can be used for more elaborate functionalities than `command`.
   */
  constructor({ dom, isActive, isEnabled, isVisible, command, exec }) {
    this.domSource = dom
    this.isActive = isActive ? isActive.bind(this) : () => false
    this.isEnabled = isEnabled ? isEnabled.bind(this) : () => true
    this.isVisible = isVisible ? isVisible.bind(this) : () => true
    this.__command = command
    this.__exec = exec
  }

  attach(dom) {
    this.dom = this.domSource(dom)
  }

  update(editorState) {
    const isActive = this.isActive(editorState)
    toggleClass(this.dom, "bg-emerald-300", isActive)

    const isEnabled = this.isEnabled(editorState)
    toggleClass(this.dom, "bg-gray-100", !isEnabled)
    toggleClass(this.dom, "text-gray-400", !isEnabled)
    toggleClass(this.dom, "pointer-events-none", !isEnabled)

    const isVisible = this.isVisible(editorState)
    toggleClass(this.dom, "hidden", !isVisible)
  }

  exec(editorView) {
    if (this.__command) {
      this.__command(editorView.state, editorView.dispatch, editorView)
    } else if (this.__exec) {
      this.__exec(editorView)
    }
  }
}
