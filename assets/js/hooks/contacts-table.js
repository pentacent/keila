/**
 * This hook is used on the Contacts table to toggle sorting.
 */
export const ContactsTable = {
  mounted() {
    const sortButtons = this.el.querySelectorAll("[data-sort-key]")
    const form = document.getElementById("search-form")

    for (let i = 0; i < sortButtons.length; i++) {
      const sortButton = sortButtons[i]
      sortButton.addEventListener("click", (e) => {
        e.preventDefault()
        const keySelect = form.querySelector("[name=sort_by]")
        keySelect.value = sortButton.dataset.sortKey
        const orderSelect = form.querySelector("[name=sort_order]")
        orderSelect.value = sortButton.dataset.sortOrder || "1"
        form.submit()
      })
    }
    const rawDate = this.el.dataset.value
    if (!rawDate) return

    const date = new Date(rawDate)
    const h = date.getHours() < 10 ? "0" + date.getHours() : date.getHours()
    const m = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
    this.el.value = `${h}:${m}`
  }
}
