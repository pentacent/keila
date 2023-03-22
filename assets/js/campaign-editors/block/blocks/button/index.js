export default class Button {
  constructor({ data, block }) {
    this.data = (data.label || data.url) ? data : { label: null, url: null, centered: false }
    this.block = block

    this.wrapper = document.createElement("div")
    this.drawView()
  }

  render() {
    return this.wrapper
  }

  drawView() {
    this.wrapper.innerHTML = ""
    this.wrapper.className = this.data.centered ? "flex flex-col items-center" : ""
    this.button = document.createElement("div")
    this.button.className = "button-contenteditable"
    this.button.style = "margin:0!important"
    this.button.setAttribute("contenteditable", true)
    this.button.innerHTML = this.data.label
    this.wrapper.appendChild(this.button)

    this.linkEditor = document.createElement("input")
    this.linkEditor.setAttribute("type", "url")
    this.linkEditor.setAttribute("placeholder", "https://www.example.org")
    this.linkEditor.className = "text-xs mt-1 w-full bg-transparent border-1 border-gray-500 border-dashed"
    this.linkEditor.value = this.data.url
    this.wrapper.appendChild(this.linkEditor)
  }

  static get toolbox() {
    return {
      title: document.querySelector("#block-container-assets .editor-button-title").innerText,
      icon: document.querySelector("#block-container-assets .icon-button-alt").innerHTML
    }
  }

  toggleCentered() {
    this.data.centered = !this.data.centered
    this.drawView()
    this.block.dispatchChange()
  }

  renderSettings() {
    return [
      {
        icon: "<->",
        label: this.data.centered
          ? document.querySelector("#block-container-assets .editor-button-make-full-width-label").innerText
          : document.querySelector("#block-container-assets .editor-button-make-centered-label").innerText,
        onActivate: () => this.toggleCentered(),
        closeOnActivate: true
      }
    ]
  }

  save(_blockContent) {
    const lastChild = this.button.lastElementChild
    if (lastChild && lastChild.tagName === "BR") lastChild.remove()
    return {
      label: this.button.innerHTML,
      url: this.linkEditor.value,
      centered: this.data.centered
    }
  }
}
