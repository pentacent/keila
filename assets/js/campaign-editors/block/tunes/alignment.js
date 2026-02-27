/**
 * This Block Tune is designed to work with the alignment inline tool and provides an API
 * to set and retrieve alignment values for blocks.
 */
const alignmentState = new Map()

/**
 * Set alignment for a block
 * @param {string} blockId - Block ID
 * @param {string} alignment - Alignment value (left, center, right, justify)
 */
export function setAlignment(blockId, alignment) {
  alignmentState.set(blockId, alignment)
}

/**
 * Get alignment for a block
 * @param {string} blockId - Block ID
 * @returns {string|undefined} - Alignment value or undefined if not set
 */
export function getAlignment(blockId) {
  return alignmentState.get(blockId)
}

/**
 * Check if alignment has been set for a block by the inline tool
 * @param {string} blockId - Block ID
 * @returns {boolean}
 */
export function hasAlignment(blockId) {
  return alignmentState.has(blockId)
}

/**
 * Clear alignment for a block (after it's been read by the tune)
 * @param {string} blockId - Block ID
 */
export function clearAlignment(blockId) {
  alignmentState.delete(blockId)
}

class AlignmentBlockTune {
  /**
   * Default alignment
   */
  static get DEFAULT_ALIGNMENT() {
    return "left"
  }

  static get isTune() {
    return true
  }

  /**
   * Get alignment based on config or default
   */
  getAlignment() {
    if (this.settings?.blocks && this.settings.blocks.hasOwnProperty(this.block.name)) {
      return this.settings.blocks[this.block.name]
    }
    if (this.settings?.default) {
      return this.settings.default
    }
    return AlignmentBlockTune.DEFAULT_ALIGNMENT
  }

  /**
   * @param {object} params - Constructor params
   * @param {object} params.api - Editor.js API
   * @param {object} params.data - Previously saved tune data
   * @param {object} params.config - Tune configuration
   * @param {object} params.block - Block API
   */
  constructor({ api, data, config, block }) {
    this.api = api
    this.block = block
    this.settings = config
    this.data = data || { alignment: this.getAlignment() }
    this.wrapper = null

    this._CSS = {
      alignment: {
        left: "ce-tune-alignment--left",
        center: "ce-tune-alignment--center",
        right: "ce-tune-alignment--right",
        justify: "ce-tune-alignment--justify"
      }
    }
  }

  /**
   * Wrap block content with alignment wrapper
   * @param {HTMLElement} blockContent - Block's content element
   * @returns {HTMLElement} - Wrapped element
   */
  wrap(blockContent) {
    this.wrapper = document.createElement("div")
    this.wrapper.classList.add(this._CSS.alignment[this.data.alignment])
    this.wrapper.append(blockContent)
    return this.wrapper
  }

  /**
   * Render tune in Block Settings menu
   * Returns empty element - alignment is controlled via inline toolbar only
   * @returns {HTMLElement}
   */
  render() {
    return document.createElement("div")
  }

  /**
   * Save tune data
   * Checks shared state for updates from inline tool
   * @returns {object} - Saved data
   */
  save() {
    // Check if inline tool updated the alignment via shared state
    if (hasAlignment(this.block.id)) {
      const newAlignment = getAlignment(this.block.id)
      this.data.alignment = newAlignment

      // Also update the wrapper class
      if (this.wrapper) {
        Object.values(this._CSS.alignment).forEach((cssClass) => {
          this.wrapper.classList.remove(cssClass)
        })
        this.wrapper.classList.add(this._CSS.alignment[newAlignment])
      }

      clearAlignment(this.block.id)
    }

    return this.data
  }
}

export default AlignmentBlockTune
