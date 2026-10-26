/**
 * This hook makes the children with `data-role="sortable-item"` of an element
 * sortable via HTML5 drag and drop. Items can be dragged by their
 * `data-role="drag-handle"`.
 *
 * The hook dispatches a change event on the item's first input when an item
 * has been moved.
 */
export const Sortable = {
  mounted() {
    this.el.addEventListener("pointerdown", (e) => this.handlePointerDown(e))
    this.el.addEventListener("dragstart", (e) => this.handleDragStart(e))
    this.el.addEventListener("dragover", (e) => this.handleDragOver(e))
    this.el.addEventListener("drop", (e) => this.handleDrop(e))
    this.el.addEventListener("dragend", () => this.handleDragEnd())
  },

  // Items are only draggable while the pointer is on their own handle, so that
  // text in their inputs can still be selected.
  handlePointerDown(e) {
    const item = this.getItem(e.target)
    if (!item) return

    const handle = e.target.closest("[data-role=drag-handle]")
    item.draggable = !!handle && handle.closest("[data-role=sortable-item]") === item
  },

  handleDragStart(e) {
    const item = this.getItem(e.target)
    if (!item || item !== e.target || !item.draggable) return

    this.draggedItem = item
    this.originalIndex = this.getItemIndex(item)
    this.dropped = false
    item.classList.add("opacity-50")

    e.dataTransfer.effectAllowed = "move"
    // Firefox only starts dragging when data is set
    e.dataTransfer.setData("text/plain", "")
  },

  handleDragOver(e) {
    if (!this.draggedItem) return
    e.preventDefault()

    const item = this.getItem(e.target)
    if (!item || item === this.draggedItem) return

    const { top, height } = item.getBoundingClientRect()
    const isAfter = e.clientY > top + height / 2
    this.el.insertBefore(this.draggedItem, isAfter ? item.nextSibling : item)
  },

  handleDrop(e) {
    if (!this.draggedItem) return
    e.preventDefault()

    this.dropped = true
  },

  handleDragEnd() {
    if (!this.draggedItem) return

    const item = this.draggedItem
    item.classList.remove("opacity-50")
    item.draggable = false
    this.draggedItem = null

    // If the drag was cancelled
    if (!this.dropped) {
      const otherItems = this.getItems().filter((el) => el !== item)
      this.el.insertBefore(item, otherItems[this.originalIndex] || null)
      return
    }

    // If the item was moved
    if (this.getItemIndex(item) !== this.originalIndex) {
      item.querySelector("input").dispatchEvent(new Event("change", { bubbles: true }))
    }
  },

  getItems() {
    return Array.from(this.el.children).filter((el) => el.dataset.role === "sortable-item")
  },

  // Returns the item of this list that contains the given element,
  // skipping the items of nested lists.
  getItem(el) {
    let item = el.closest("[data-role=sortable-item]")

    while (item && item.parentElement !== this.el) {
      item = item.parentElement.closest("[data-role=sortable-item]")
    }

    return item
  },

  getItemIndex(item) {
    return this.getItems().indexOf(item)
  }
}
