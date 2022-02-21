import { defaultMarkdownSerializer } from "prosemirror-markdown"

const markdownSerializer = defaultMarkdownSerializer
markdownSerializer.marks.liquid = { open: "", close: "", mixable: false, escape: false}

export { markdownSerializer }
