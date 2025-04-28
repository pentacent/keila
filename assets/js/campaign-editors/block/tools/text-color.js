export default class TextColor {
  static get isInline() {
    return true
  }

  get state() {
    return this.active
  }

  set state(enable) {
    this.active = enable

    this.button.classList.toggle(this.api.styles.inlineToolButtonActive, enable)
  }

  constructor({ api }) {
    this.api = api
    this.button = null
    this.active = false

    this.tag = "SPAN"
    this.class = "text-color"
    this.selector = `${this.tag}.${this.class}`
  }

  render() {
    this.button = document.createElement("button")
    this.button.type = "button"
    this.button.innerHTML = `<span class="text-s bold px-1">A</span>`
    this.colorIndicator = document.createElement("span")
    this.button.classList.add(this.api.styles.inlineToolButton)
    this.button.style.position = "relative"
    this.colorIndicator.style.height = "6px"
    this.colorIndicator.style.display = "block"
    this.colorIndicator.style.position = "absolute"
    this.colorIndicator.style.left = "0px"
    this.colorIndicator.style.right = "0px"
    this.colorIndicator.style.bottom = "2px"
    this.colorIndicator.style.borderRadius = "2px"
    this.button.appendChild(this.colorIndicator)

    this.colorPicker = document.createElement("input")
    this.colorPicker.type = "color"
    this.colorPicker.hidden = true

    return this.button
  }

  surround(range) {
    this.unwrap(range)

    if (this.handler) {
      this.colorPicker.removeEventListener("input", this.handler)
    }
    this.handler = () => {
      this.wrap(range)
      this.checkState()
    }
    this.colorPicker.addEventListener("input", this.handler)
    this.colorPicker.click()
  }

  wrap(range) {
    const selectedText = range.extractContents()
    const mark = document.createElement(this.tag)
    mark.className = this.class
    mark.style.color = this.colorPicker.value
    mark.appendChild(selectedText)
    range.insertNode(mark)

    this.api.selection.expandToTag(mark)
  }

  moveAndSelectNodes(range, node, nodes) {
    const parentNode = node.parentNode

    const anchorBefore = document.createElement("span")
    parentNode.insertBefore(anchorBefore, node)
    parentNode.insertBefore(nodes, node)
    const anchorAfter = document.createElement("span")
    parentNode.insertBefore(anchorAfter, node)

    range.setStartAfter(anchorBefore)
    range.setEndBefore(anchorAfter)
    anchorBefore.remove()
    anchorAfter.remove()
  }

  unwrap(range) {
    const rangeContainer = range.commonAncestorContainer
    const contents = range.extractContents()

    // If rangeContainer is inside color mark
    let markParent = rangeContainer.nodeType === Node.ELEMENT_NODE
      ? rangeContainer.closest(this.selector)
      : rangeContainer.parentNode.closest(this.selector)
    if (markParent === rangeContainer) markParent = rangeContainer.parentNode
    if (markParent) {
      const before = rangeContainer
      const after = rangeContainer.splitText(range.startOffset)

      const rangeBefore = document.createRange()
      rangeBefore.selectNode(markParent)
      rangeBefore.setEndAfter(before)

      const rangeAfter = document.createRange()
      rangeAfter.selectNode(markParent)
      rangeAfter.setStartBefore(after)

      markParent.parentNode.insertBefore(
        rangeBefore.extractContents(),
        markParent
      )
      this.moveAndSelectNodes(range, markParent, contents)
      markParent.parentNode.insertBefore(
        rangeAfter.extractContents(),
        markParent
      )

      const selection = document.getSelection()
      selection.empty()
      selection.addRange(range)

      return
    }

    // Selection spans more than a single color mark
    contents.querySelectorAll(`${this.tag}.${this.class}`).forEach((mark) => {
      while (mark.firstChild) {
        mark.parentNode.insertBefore(mark.firstChild, mark)
      }
      mark.remove()
    })
    range.insertNode(contents)
  }

  checkState() {
    const mark = this.api.selection.findParentTag(this.tag)
    this.active = !!mark && mark.matches(`.${this.class}`)

    if (this.active) {
      const { color } = mark.style
      this.colorIndicator.style.backgroundColor = color
    } else {
      this.colorIndicator.style.backgroundColor = "transparent"
    }
  }
  static get sanitize() {
    return {
      span: {
        class: "text-color",
        style: true
      }
    }
  }
}
