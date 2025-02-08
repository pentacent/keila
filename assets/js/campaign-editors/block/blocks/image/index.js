export default class Image {
  constructor({ data, api, block }) {
    this.api = api
    this.block = block
    this.data = data.image
      ? data
      : { caption: null, alt: null, title: null, image: { id: null, src: null }, link: { url: null } }
    this.config = data.config

    this.wrapper = document.createElement("div")
    this.drawView()
  }

  render() {
    return this.wrapper
  }

  drawView() {
    this.wrapper.innerHTML = ""
    this.wrapper.className = "image-block"

    if (this.isEmpty()) {
      const placeholder = document.createElement("div")
      placeholder.innerHTML = document.querySelector("#block-container-assets .image-placeholder").innerHTML
      this.wrapper.appendChild(placeholder)
      this.addClickHandler(placeholder)
    } else {
      const img = document.createElement("img")
      img.src = this.data.image.src
      img.className = "cursor-pointer"
      this.wrapper.appendChild(img)

      this.addClickHandler(img)

      const captionEditor = document.createElement("div")
      this.captionEditor = captionEditor
      captionEditor.dataset.placeholder =
        document.querySelector("#block-container-assets .image-caption-placeholder").innerText
      captionEditor.setAttribute("contenteditable", true)
      captionEditor.innerHTML = this.data.caption
      captionEditor.className = "mt-2 w-full"
      captionEditor.addEventListener("focusout", () => {
        if (captionEditor.innerText.trim() === "") {
          captionEditor.innerHTML = ""
        }
      })
      this.wrapper.appendChild(captionEditor)

      const linkEditor = document.createElement("input")
      this.linkEditor = linkEditor
      linkEditor.setAttribute("type", "url")
      const linkEditorPlaceholder = document.querySelector("#block-container-assets .image-url-placeholder").innerText
      linkEditor.setAttribute("placeholder", linkEditorPlaceholder)
      linkEditor.className = "text-xs mt-1 w-full bg-transparent border-1 border-gray-500 border-dashed"
      linkEditor.value = this.data.url || ""
      this.wrapper.appendChild(linkEditor)
    }

    return this.wrapper
  }

  addClickHandler(element) {
    element.addEventListener("click", e => {
      this.openDialog()
    })
  }

  isEmpty() {
    return !(this.data.image && this.data.image.src)
  }

  save(_blockContent) {
    this.data.caption = this.captionEditor ? this.captionEditor.innerHTML : null
    this.data.url = this.linkEditor ? this.linkEditor.value : null
    return this.data
  }

  validate(_savedData) {
    return true
  }

  static get sanitize() {
    return {
      caption: {
        br: false
      }
    }
  }

  static get toolbox() {
    return {
      title: document.querySelector("#block-container-assets .editor-image-title").innerText,
      icon: document.querySelector("#block-container-assets .icon-photograph").innerHTML
    }
  }

  renderSettings() {
    return [
      {
        icon: document.querySelector("#block-container-assets .icon-photograph").innerHTML,
        label: document.querySelector("#block-container-assets .editor-image-edit-label").innerText,
        onActivate: () => this.openDialog(),
        closeOnActivate: true
      }
    ]
  }

  openDialog() {
    document
      .querySelector("[data-dialog-for=image]")
      .dispatchEvent(new CustomEvent("x-show", { detail: this.data.image }))

    window.addEventListener("update-image", e => {
      const { src, alt, title, id } = e.detail
      const image = { src, alt, title, id }
      if (!e.detail.cancel) {
        this.data.image = image
        this.drawView()
      }

      this.api.caret.focus()
      this.api.caret.setToBlock()
      this.block.dispatchChange()
    }, { once: true })
  }
}
