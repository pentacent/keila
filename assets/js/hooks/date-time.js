/**
 * This hook can be used on inputs with type=time.
 * Specify a UTC ISO 8601 string as data-value.
 */
export const SetLocalTimeValue = {
  mounted() {
    const rawDate = this.el.dataset.value
    if (!rawDate) return

    const date = new Date(rawDate)
    const h = date.getHours() < 10 ? "0" + date.getHours() : date.getHours()
    const m = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
    this.el.value = `${h}:${m}`
  }
}

/**
 * This hook can be used on inputs with type=date.
 * Specify a UTC ISO 8601 string as data-value.
 */
export const SetLocalDateValue = {
  mounted() {
    const rawDate = this.el.dataset.value
    if (!rawDate) return

    const date = new Date(rawDate)
    const y = date.getFullYear()
    const m = (date.getMonth() + 1) < 10 ? "0" + (date.getMonth() + 1) : (date.getMonth() + 1)
    const d = date.getDate() < 10 ? "0" + date.getDate() : date.getDate()
    this.el.value = `${y}-${m}-${d}`
  }
}

/**
 * This hook replaces the inner text of an element with a formatted local date.
 * Specify a UTC ISO 8601 string as data-value.
 */
const putLocalDateTime = el => {
  const rawDate = el.dataset.value
  if (!rawDate) return

  const date = new Date(rawDate)
  el.innerText = date.toLocaleString(undefined, {
    weekday: "short",
    year: "numeric",
    month: "short",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: el.dataset.resolution === "second" ? "2-digit" : undefined
  })
}
export const SetLocalDateTimeContent = {
  mounted() {
    putLocalDateTime(this.el)
  },
  updated() {
    putLocalDateTime(this.el)
  }
}
