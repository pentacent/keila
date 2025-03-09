import EditorJS from "@editorjs/editorjs"

// Make Tailwind pick up on these classes and include them
const _requiredClasses = "grid-cols-2 grid-cols-3 col-span-1 col-span-2 col-span-3"

export default class Layout {
  constructor({ data, config, api, block }) {
    this.data = data.blocks && data.ratio ? data : { blocks: [], columns: 2, ratio: "1-1" }
    this.editors = []
    this.config = config

    this.wrapper = document.createElement("div")
    this.drawView()
    this.api = api
    this.block = block
  }

  render() {
    return this.wrapper
  }

  drawView() {
    this.wrapper.innerHTML = ""
    const colSpans = this.data.ratio.split("-").map(colSpan => parseInt(colSpan))
    const colSpanTotal = colSpans.reduce((acc, i) => acc + i)
    this.wrapper.className = `layout-block grid grid-cols-${colSpanTotal} gap-4`
    this.editors = []

    for (let i = 0; i < this.data.columns; i++) {
      const editorContainer = document.createElement("div")
      editorContainer.className = `col-span-${colSpans[i]}`
      this.wrapper.appendChild(editorContainer)

      const editorPlace = document.createElement("div")
      editorPlace.className = "p-0 bg-blue-200"
      editorContainer.appendChild(editorPlace)
      const editor = new EditorJS({
        holder: editorPlace,
        tools: this.config.tools,
        data: this.data.blocks[i],
        placeholder: document.querySelector("#block-container-assets .editor-layout-placeholder").innerText,
        onChange: () => {
          this.block.dispatchChange()
        }
      })
      this.editors.push(editor)

      editorPlace.addEventListener("keydown", e => {
        if (e.key === "Enter") {
          e.preventDefault()
          e.stopPropagation()
        }

        if (e.key === "Backspace") {
          e.stopPropagation()
        }

        if (e.key === "Tab") {
          e.preventDefault()
          e.stopPropagation()
        }
      })

      // NOTE: This variable keeps track of whether
      // we've manually opened or closed the toolbar.
      // This is necessary because the API doesn't expose
      // the toolbar state
      let maybeOpen = false

      editorPlace.addEventListener("mouseenter", () => {
        if (!maybeOpen) editor.toolbar.open()
        maybeOpen = true
      })

      editorPlace.addEventListener("mouseleave", () => {
        editor.toolbar.close()
        maybeOpen = false
      })

      editorPlace.addEventListener("paste", e => {
        e.preventDefault()
        e.stopPropagation()
      })
    }

    return this.wrapper
  }

  updateColumns(ratio) {
    this.data.ratio = ratio
    this.data.columns = ratio.match(/\d+/g).length
    this.block.dispatchChange()
    this.drawView()
  }

  renderSettings() {
    const settings = [
      {
        name: "1-1",
        icon:
          "<div class=\"grid grid-cols-2 gap-1 h-6 w-full p-1\"><div class=\"bg-gray-500\"></div><div class=\"bg-gray-500\"></div></div>",
        action: () => this.updateColumns("1-1")
      },
      {
        name: "1-2",
        icon:
          "<div class=\"grid grid-cols-3 gap-1 h-6 w-full p-1\"><div class=\"bg-gray-500\"></div><div class=\"bg-gray-500 col-span-2\"></div></div>",
        action: () => this.updateColumns("1-2")
      },
      {
        name: "2-1",
        icon:
          "<div class=\"grid grid-cols-3 gap-1 h-6 w-full p-1\"><div class=\"bg-gray-500 col-span-2\"></div><div class=\"bg-gray-500\"></div></div>",
        action: () => this.updateColumns("2-1")
      },
      {
        name: "1-1-1",
        icon:
          "<div class=\"grid grid-cols-3 gap-1 h-6 w-full p-1\"><div class=\"bg-gray-500\"></div><div class=\"bg-gray-500\"></div><div class=\"bg-gray-500\"></div></div>",
        action: () => this.updateColumns("1-1-1")
      }
    ]

    return settings.map(setting => {
      return {
        icon: setting.icon,
        label: setting.name,
        onActivate: setting.action,
        closeOnActivate: true,
        isActive: this.data.ratio === setting.name
      }
    })
  }

  async save(_blockContent) {
    const blocks = await Promise.all(this.editors.map(editor => editor.save()))
    this.data.blocks = blocks
    return this.data
  }

  static get contentless() {
    return true
  }

  static get toolbox() {
    return {
      title: "Layout",
      icon: document.querySelector("#block-container-assets .icon-block").innerHTML
    }
  }
}
