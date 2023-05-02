import markdownit from "markdown-it"
import { MarkdownParser } from "prosemirror-markdown"
import { markdownItLiquid } from "./markdown-it-liquid"
import { markdownItLinkWithLiquid } from "./markdown-it/link-with-liquid"
import { schema } from "./markdown-schema"

const md = markdownit("commonmark", { html: false })
  .use(markdownItLiquid)
  .use(markdownItLinkWithLiquid)

// Markdown parser based on Prosemirror’s defaultMarkdownParser
// Extended with Liquid tag
function listIsTight(tokens, i) {
  while (++i < tokens.length) {
    if (tokens[i].type != "list_item_open") return tokens[i].hidden
  }
  return false
}

export const markdownParser = new MarkdownParser(schema, md, {
  blockquote: { block: "blockquote" },
  paragraph: { block: "paragraph" },
  list_item: { block: "list_item" },
  bullet_list: {
    block: "bullet_list",
    getAttrs: (_, tokens, i) => ({ tight: listIsTight(tokens, i) })
  },
  ordered_list: {
    block: "ordered_list",
    getAttrs: (tok, tokens, i) => ({
      order: +tok.attrGet("start") || 1,
      tight: listIsTight(tokens, i)
    })
  },
  heading: {
    block: "heading",
    getAttrs: tok => ({ level: +tok.tag.slice(1) })
  },
  code_block: { block: "code_block", noCloseToken: true },
  fence: {
    block: "code_block",
    getAttrs: tok => ({ params: tok.info || "" }),
    noCloseToken: true
  },
  hr: { node: "horizontal_rule" },
  image: {
    node: "image",
    getAttrs: tok => ({
      src: tok.attrGet("src"),
      title: tok.attrGet("title") || null,
      alt: tok.children[0] && tok.children[0].content || null
    })
  },
  hardbreak: { node: "hard_break" },
  liquid: { mark: "liquid" },
  em: { mark: "em" },
  strong: { mark: "strong" },
  link: {
    mark: "link",
    getAttrs: tok => ({
      href: tok.attrGet("href"),
      title: tok.attrGet("title") || null
    })
  },
  code_inline: { mark: "code", noCloseToken: true }
})
