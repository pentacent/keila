const putHtmlPreview = (el) => {
  const content = el.innerText
  if (!content) return

  const iframe = document.getElementById(el.dataset.iframe)
  if (!iframe) return

  const doc = iframe.contentDocument
  doc.open()
  doc.write(content)
  doc.close()
}

export default {
  HtmlPreview: {
    mounted() {
      putHtmlPreview(this.el)
    },
    updated() {
      putHtmlPreview(this.el)
    }
  }
}
