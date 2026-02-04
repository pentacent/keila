import { getAlignment, setAlignment } from "../tunes/alignment"

/**
 * Allowed block types for the alignment inline tool
 */
const ALLOWED_BLOCK_TYPES = ["paragraph", "header"]

function getText(key) {
  const element = document.querySelector(
    `#block-container-assets .editor-alignment-${key}`
  )
  return element.innerText
}

function getIcon(iconName) {
  const element = document.querySelector(
    `#block-container-assets .icon-${iconName}`
  )
  if (!element) return ""
  return element.innerHTML
}

export default class Alignment {
  static get isInline() {
    return true
  }

  constructor({ api }) {
    this.api = api
    this.button = null
    this.dropdown = null
    this.currentAlignment = "left"
    this.isAllowedBlock = false

    this.alignments = [
      { name: "left", icon: "align-left", label: "left" },
      { name: "justify", icon: "align-justify", label: "justify" },
      { name: "center", icon: "align-center", label: "center" },
      { name: "right", icon: "align-right", label: "right" }
    ]

    this.CSS = {
      alignment: {
        left: "ce-tune-alignment--left",
        justify: "ce-tune-alignment--justify",
        center: "ce-tune-alignment--center",
        right: "ce-tune-alignment--right"
      }
    }

    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  render() {
    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.classList.add(this.api.styles.inlineToolButton)
    this.updateButtonIcon()

    return this.button
  }

  updateButtonIcon() {
    const alignment = this.alignments.find((a) => a.name === this.currentAlignment)
      || this.alignments[0]
    this.button.innerHTML = getIcon(alignment.icon)
    const svg = this.button.querySelector("svg")
    if (svg) {
      svg.style.height = "15px"
    }
  }

  surround(range) {
    if (!this.isAllowedBlock) {
      return
    }
    this.showDropdown()
  }

  showDropdown() {
    if (this.dropdown) {
      this.closeDropdown()
      return
    }

    this.button.classList.add("ce-inline-tool--open-dropdown")
    const buttonRect = this.button.getBoundingClientRect()
    this.dropdown = document.createElement("div")
    this.dropdown.classList.add("alignment-dropdown")
    this.dropdown.style.position = "absolute"
    this.dropdown.style.top = `${buttonRect.bottom + window.scrollY + 4}px`
    this.dropdown.style.left = `${buttonRect.left + window.scrollX}px`
    this.dropdown.style.backgroundColor = "#fff"
    this.dropdown.style.border = "1px solid #ccc"
    this.dropdown.style.borderRadius = "4px"
    this.dropdown.style.boxShadow = "0 2px 8px rgba(0,0,0,0.15)"
    this.dropdown.style.zIndex = "10000"
    this.dropdown.style.minWidth = "120px"

    this.alignments.forEach((alignment) => {
      const option = document.createElement("button")
      option.type = "button"
      option.style.display = "flex"
      option.style.alignItems = "center"
      option.style.gap = "8px"
      option.style.width = "100%"
      option.style.padding = "8px 12px"
      option.style.border = "none"
      option.style.backgroundColor = alignment.name === this.currentAlignment ? "#f0f0f0" : "transparent"
      option.style.cursor = "pointer"
      option.style.textAlign = "left"
      option.style.fontFamily = "inherit"
      option.style.fontSize = "14px"

      const iconSpan = document.createElement("span")
      iconSpan.innerHTML = getIcon(alignment.icon)
      iconSpan.style.display = "flex"
      iconSpan.style.alignItems = "center"
      iconSpan.style.width = "15px"

      const labelSpan = document.createElement("span")
      labelSpan.textContent = getText(alignment.label)

      option.appendChild(iconSpan)
      option.appendChild(labelSpan)

      option.addEventListener("mouseenter", () => {
        option.style.backgroundColor = "#f0f0f0"
      })

      option.addEventListener("mouseleave", () => {
        option.style.backgroundColor = alignment.name === this.currentAlignment ? "#f0f0f0" : "transparent"
      })

      option.addEventListener("mousedown", (e) => {
        e.preventDefault()
        e.stopPropagation()
      })

      option.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.applyAlignment(alignment.name)
        this.closeDropdown()
      })

      this.dropdown.appendChild(option)
    })

    document.body.appendChild(this.dropdown)

    setTimeout(() => {
      document.addEventListener("mousedown", this.outsideClickHandler)
    }, 10)
  }

  handleOutsideClick(e) {
    if (
      this.dropdown
      && !this.dropdown.contains(e.target)
      && !this.button.contains(e.target)
    ) {
      this.closeDropdown()
    }
  }

  closeDropdown() {
    if (this.dropdown) {
      this.dropdown.remove()
      this.dropdown = null
    }
    this.button.classList.remove("ce-inline-tool--open-dropdown")
    document.removeEventListener("mousedown", this.outsideClickHandler)
  }

  applyAlignment(alignmentName) {
    const currentIndex = this.api.blocks.getCurrentBlockIndex()
    const block = this.api.blocks.getBlockByIndex(currentIndex)

    if (block) {
      // Store in shared state using block ID
      setAlignment(block.id, alignmentName)

      // Also update the visual CSS classes on the wrapper
      const wrapper = this.findTuneWrapper(block)
      if (wrapper) {
        Object.values(this.CSS.alignment).forEach((cssClass) => {
          wrapper.classList.remove(cssClass)
        })
        wrapper.classList.add(this.CSS.alignment[alignmentName])
      }

      // Trigger change event so Editor.js knows to save
      block.dispatchChange()
    }

    this.currentAlignment = alignmentName
    this.updateButtonIcon()
  }

  findTuneWrapper(block) {
    if (block && block.holder) {
      const contentHolder = block.holder.querySelector(".ce-block__content")
      if (contentHolder) {
        // Find element with any of the alignment classes
        for (const alignment of Object.keys(this.CSS.alignment)) {
          const wrapper = contentHolder.querySelector(
            `.${this.CSS.alignment[alignment]}`
          )
          if (wrapper) {
            return wrapper
          }
        }
        // If no alignment class found, the wrapper might be the first child div
        const firstChild = contentHolder.firstElementChild
        if (firstChild && firstChild.tagName === "DIV") {
          return firstChild
        }
      }
    }
    return null
  }

  async checkState() {
    const currentIndex = this.api.blocks.getCurrentBlockIndex()
    const block = this.api.blocks.getBlockByIndex(currentIndex)

    if (block) {
      // Check if this block type is allowed
      this.isAllowedBlock = ALLOWED_BLOCK_TYPES.includes(block.name)
      this.button.style.display = this.isAllowedBlock ? "" : "none"

      if (!this.isAllowedBlock) {
        return
      }

      // First check shared state (set by this inline tool)
      const storedAlignment = getAlignment(block.id)
      if (storedAlignment) {
        this.currentAlignment = storedAlignment
      } else {
        // Try to read from the block's saved tune data
        try {
          const savedData = await block.save()
          if (
            savedData
            && savedData.tunes
            && savedData.tunes.alignment
            && savedData.tunes.alignment.alignment
          ) {
            this.currentAlignment = savedData.tunes.alignment.alignment
          } else {
            // Fall back to checking CSS classes on the wrapper
            this.currentAlignment = this.getAlignmentFromWrapper(block)
          }
        } catch (e) {
          // Fall back to checking CSS classes on the wrapper
          this.currentAlignment = this.getAlignmentFromWrapper(block)
        }
      }
    } else {
      this.currentAlignment = "left"
      this.isAllowedBlock = false
      this.button.style.display = "none"
    }

    this.updateButtonIcon()
  }

  getAlignmentFromWrapper(block) {
    const wrapper = this.findTuneWrapper(block)
    if (wrapper) {
      for (const [alignment, cssClass] of Object.entries(this.CSS.alignment)) {
        if (wrapper.classList.contains(cssClass)) {
          return alignment
        }
      }
    }
    return "left"
  }

  clear() {
    this.closeDropdown()
  }
}
