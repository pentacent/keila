function getIcon(iconName) {
  const element = document.querySelector(
    `#block-container-assets .icon-${iconName}`
  )
  if (!element) return ""
  return element.innerHTML
}

function getAlignmentLabel(key) {
  const element = document.querySelector(
    `#block-container-assets .editor-alignment-${key}`
  )
  if (!element) return key
  return element.innerText
}

const ALIGNMENTS = [
  { name: "left", icon: "align-left", label: "left" },
  { name: "center", icon: "align-center", label: "center" },
  { name: "right", icon: "align-right", label: "right" }
]

export default class Image {
  constructor({ data, api, block }) {
    this.api = api
    this.block = block
    this.data = data.image
      ? data
      : { caption: null, alt: null, title: null, width: null, image: { id: null, src: null }, link: { url: null } }
    this.config = data.config

    if (!this.data.tunes) {
      this.data.tunes = {}
    }
    if (!this.data.tunes.alignment) {
      this.data.tunes.alignment = "left"
    }

    this.resizeObserver = null
    this.wrapper = document.createElement("div")
    this.drawView()
  }

  render() {
    return this.wrapper
  }

  drawView() {
    if (this.isEmpty() || !this.img) {
      this.wrapper.innerHTML = ""

      this.imgContainer = null
      this.img = null
      this.captionEditor = null
      this.linkEditor = null
    }
    this.wrapper.className = "image-block"

    const alignment = this.data.tunes.alignment || "left"
    this.wrapper.style.display = "flex"
    this.wrapper.style.flexDirection = "column"
    const alignItems = alignment === "center" ? "center" : alignment === "right" ? "flex-end" : "flex-start"
    this.wrapper.style.alignItems = alignItems

    if (this.isEmpty()) {
      const placeholder = document.createElement("div")
      placeholder.innerHTML = document.querySelector("#block-container-assets .image-placeholder").innerHTML
      this.wrapper.appendChild(placeholder)
      this.addClickHandler(placeholder)
    } else {
      const imgContainer = this.imgContainer || document.createElement("div")
      imgContainer.style.overflow = "hidden"
      imgContainer.style.resize = "horizontal"
      imgContainer.style.maxWidth = "100%"
      imgContainer.style.minWidth = "32px"
      if (this.data.width) {
        imgContainer.style.width = this.data.width + "px"
      }
      if (!imgContainer.isConnected) {
        this.wrapper.appendChild(imgContainer)
        this.setupResizeObserver(imgContainer)
      }
      this.imgContainer = imgContainer

      const img = this.img || document.createElement("img")
      img.src = this.data.image.src
      img.style.display = "block"
      img.style.width = "100%"
      img.style.cursor = "pointer"
      if (!img.isConnected) {
        imgContainer.appendChild(img)
        this.addClickHandler(img)
      }
      this.img = img

      const captionEditor = this.captionEditor || document.createElement("div")
      this.captionEditor = captionEditor
      captionEditor.dataset.placeholder =
        document.querySelector("#block-container-assets .image-caption-placeholder").innerText
      captionEditor.setAttribute("contenteditable", true)
      captionEditor.innerHTML = this.data.caption
      captionEditor.className = "mt-2 w-full"
      captionEditor.style.textAlign = alignment
      if (!captionEditor.isConnected) {
        this.wrapper.appendChild(captionEditor)
        captionEditor.addEventListener("focusout", () => {
          if (captionEditor.innerText.trim() === "") {
            captionEditor.innerHTML = ""
          }
        })
      }
      this.captionEditor = captionEditor

      const linkEditor = this.linkEditor || document.createElement("input")
      linkEditor.setAttribute("type", "url")
      const linkEditorPlaceholder = document.querySelector("#block-container-assets .image-url-placeholder").innerText
      linkEditor.setAttribute("placeholder", linkEditorPlaceholder)
      linkEditor.className = "text-xs mt-1 w-full bg-transparent border-1 border-gray-500 border-dashed"
      linkEditor.value = this.data.url || ""
      if (!linkEditor.isConnected) {
        this.wrapper.appendChild(linkEditor)
      }
      this.linkEditor = linkEditor
    }

    return this.wrapper
  }

  setupResizeObserver(img) {
    if (!this.resizeObserver) {
      this.resizeObserver = new ResizeObserver((entries) => {
        const entry = entries[0]
        const width = Math.round(entry.contentRect.width)

        if (width > 0 && width !== this.data.width) {
          this.data.width = width
          this.block.dispatchChange()
        }
      })
    } else {
      this.resizeObserver.disconnect()
    }

    this.resizeObserver.observe(img)
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
      icon: getIcon("photograph")
    }
  }

  renderSettings() {
    const alignmentItems = ALIGNMENTS.map(alignment => ({
      icon: getIcon(alignment.icon),
      label: getAlignmentLabel(alignment.label),
      isActive: this.data.tunes.alignment === alignment.name,
      closeOnActivate: true,
      onActivate: () => {
        this.data.tunes.alignment = alignment.name
        this.drawView()
        this.block.dispatchChange()
      }
    }))

    return [
      {
        label: document.querySelector("#block-container-assets .editor-image-edit-label").innerText,
        icon: getIcon("photograph"),
        onActivate: () => this.openDialog(),
        closeOnActivate: true
      },
      ...alignmentItems
    ]
  }

  openDialog() {
    const detail = { ...this.data.image }
    if (this.data.width) detail.width = this.data.width

    document
      .querySelector("[data-dialog-for=image]")
      .dispatchEvent(new CustomEvent("x-show", { detail }))

    window.addEventListener("update-image", e => {
      const { src, alt, title, id, width } = e.detail
      const image = { src, alt, title, id }
      if (!e.detail.cancel) {
        this.data.image = image
        this.data.width = width ? Number(width) : null
        this.drawView()
      }

      this.api.caret.focus()
      this.api.caret.setToBlock()
      this.block.dispatchChange()
    }, { once: true })
  }

  destroy() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }
}
