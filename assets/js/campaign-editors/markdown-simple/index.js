const insertText = (editor, text, selectionStart, selectionEnd, newlinesRequiredBefore, newlinesRequiredAfter) => {
  const textBefore = editor.value.slice(0, selectionStart)
  const textAfter = editor.value.slice(selectionEnd, editor.value.length)

  if (newlinesRequiredBefore && textBefore) {
    for (let i = 1; i <= newlinesRequiredBefore; i++) {
      if (textBefore[textBefore.length - i] !== "\n") {
        text = "\n" + text
      }
    }
  }
  if (newlinesRequiredAfter && textAfter) {
    for (let i = 0; i < newlinesRequiredAfter; i++) {
      if (textAfter[i] !== "\n") {
        text = text + "\n"
      }
    }
  }

  editor.value = textBefore
    + text
    + textAfter

  editor.dispatchEvent(new Event("change", { bubbles: true }))

  editor.focus()
  editor.selectionStart = selectionStart + text.length
  editor.selectionEnd = editor.selectionStart
}

export default class MarkdownSimpleEditor {
  constructor(place) {
    const editor = place.querySelector("textarea")

    place.addEventListener("x-show-image-dialog", () => {
      const { selectionStart, selectionEnd } = editor

      document.querySelector("[data-dialog-for=image]").dispatchEvent(
        new CustomEvent("x-show", { detail: {} })
      )
      window.addEventListener("update-image", e => {
        const { src, alt, title } = e.detail
        if (!src) {
          editor.selectionStart = selectionStart
          editor.focus()
          return
        }

        const altStr = alt || ""
        const titleStr = title ? ` "${title}"` : ""
        const srcTitleStr = `${src}${titleStr}`
        const imageMarkdown = `![${altStr}](${srcTitleStr})`
        insertText(editor, imageMarkdown, selectionStart, selectionEnd, 2, 2)
      }, { once: true })
    })

    place.addEventListener("x-show-link-dialog", () => {
      const { selectionStart, selectionEnd } = editor
      document.querySelector("[data-dialog-for=link]").dispatchEvent(
        new CustomEvent("x-show", { detail: {} })
      )
      window.addEventListener("update-link", e => {
        const { href, title } = e.detail
        if (!href) {
          editor.selectionStart = selectionStart
          editor.focus()
          return
        }

        const titleStr = title || ""
        const linkMarkdown = `[${titleStr}](${href})`
        insertText(editor, linkMarkdown, selectionStart, selectionEnd)
      }, { once: true })
    })

    place.addEventListener("x-show-button-dialog", () => {
      const { selectionStart, selectionEnd } = editor
      document.querySelector("[data-dialog-for=button]").dispatchEvent(
        new CustomEvent("x-show", { detail: {} })
      )
      window.addEventListener("update-button", e => {
        const { href, text } = e.detail
        if (!href) {
          editor.selectionStart = selectionStart
          editor.focus()
          return
        }

        const textStr = text || ""
        const buttonMarkdown = `#### [${textStr}](${href})`
        insertText(editor, buttonMarkdown, selectionStart, selectionEnd, 2, 2)
      }, { once: true })
    })
  }
}
