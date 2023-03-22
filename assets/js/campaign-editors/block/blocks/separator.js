export default class Separator {
  constructor(_data) {
    this.data = {}
  }

  render() {
    const el = document.createElement("div")
    el.appendChild(document.createElement("hr"))

    return el
  }

  save(_blockContent) {
    return {}
  }

  static get contentless() {
    return true
  }

  static get toolbox() {
    return {
      title: document.querySelector("#block-container-assets .editor-separator-title").innerText,
      icon: document.querySelector("#block-container-assets .icon-horizontal-rule").innerHTML
    }
  }
}
