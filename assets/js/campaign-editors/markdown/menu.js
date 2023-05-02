import { toggleMark } from "prosemirror-commands"
import { liftListItem, sinkListItem, wrapInList } from "prosemirror-schema-list"
import { NodeSelection, Plugin, Selection, TextSelection } from "prosemirror-state"
import { canInsert, hasActiveMark, hasActiveNodeType, toggleBlockType } from "./helpers"
import { markdownParser } from "./markdown-parser"
import { schema } from "./markdown-schema"
import { MenuButton } from "./menu-button"

/** Class for handling editor menus. */
class MenuView {
  /**
   * Initializes a new editor menu.
   * @param {MenuButton[]} items - MenuButtons
   * @param {Object} editorView - ProseMirror EditorView
   */
  constructor(items, editorView) {
    this.items = items
    this.editorView = editorView
    this.dom = editorView.dom.parentNode.parentNode.querySelector(".wysiwyg--menu")

    items.forEach((item) => item.attach(editorView.dom.parentNode.parentNode))

    this.update()

    this.dom.addEventListener("click", e => {
      e.preventDefault()
    })

    this.dom.addEventListener("mousedown", e => {
      e.stopPropagation()
      e.preventDefault()
      editorView.focus()
      const activatedItem = items.find(({ dom }) => dom.contains(e.target))
      if (activatedItem) activatedItem.exec(editorView)
    }, true)
  }

  update() {
    this.items.forEach(item => item.update(this.editorView.state))
  }

  destroy() {
    this.dom.remove()
  }
}

/** Plugin for attaching a `MenuView` to a ProseMirror editor */
export function buildMenu(items) {
  return new Plugin({
    view(editorView) {
      const menuView = new MenuView(items, editorView)
      return menuView
    }
  })
}

/** Menu for the Keila CampaignEditLive page */
export function buildDefaultMenu() {
  const findButton = action => {
    return el => el.querySelector(`[data-action=${action}]`)
  }

  const buttonBold = new MenuButton({
    command: toggleMark(schema.marks.strong),
    dom: findButton("strong"),
    isActive: state => hasActiveMark(state, schema.marks.strong),
    isEnabled: state => !state.selection.empty
  })

  const buttonItalic = new MenuButton({
    command: toggleMark(schema.marks.em),
    dom: findButton("em"),
    isActive: state => hasActiveMark(state, schema.marks.em),
    isEnabled: state => !state.selection.empty
  })

  const buttonLink = new MenuButton({
    exec: (editorView) => {
      if (hasActiveMark(editorView.state, schema.marks.link)) {
        return toggleMark(schema.marks.link)(editorView.state, editorView.dispatch)
      }

      document.querySelector("[data-dialog-for=link]").dispatchEvent(new CustomEvent("x-show", { detail: {} }))
      window.addEventListener("update-link", e => {
        const link = e.detail
        if (!link.cancel && link.href) {
          toggleMark(schema.marks.link, link)(editorView.state, editorView.dispatch)
        }
        editorView.focus()
      }, { once: true })
    },
    dom: findButton("link"),
    isActive: state => hasActiveMark(state, schema.marks.link),
    isEnabled: state => !state.selection.empty
  })

  const buttonImage = new MenuButton({
    exec: editorView => {
      let detail = {}

      const { _$from, _to, node } = editorView.state.selection
      if (node && node.type === schema.nodes.image) {
        detail.src = node.attrs.src
        detail.alt = node.attrs.alt
        detail.title = node.attrs.title
        detail.tab = "url"
      }

      document.querySelector("[data-dialog-for=image]").dispatchEvent(new CustomEvent("x-show", { detail }))
      window.addEventListener("update-image", e => {
        const image = e.detail
        if (!image.cancel && image.src) {
          editorView.dispatch(editorView.state.tr.replaceSelectionWith(schema.nodes.image.createAndFill(image)))
        }
        editorView.focus()
      }, { once: true })
    },
    dom: findButton("img"),
    isActive: _state => false,
    isEnabled: state => canInsert(state, schema.nodes.image)
  })

  const buttonButton = new MenuButton({
    exec: editorView => {
      document.querySelector("[data-dialog-for=button]").dispatchEvent(new CustomEvent("x-show", { detail: {} }))
      window.addEventListener("update-button", e => {
        const button = e.detail
        if (!button.cancel && button.href) {
          const link = schema.text(button.text || "Button", [schema.marks.link.create({ href: button.href })])
          editorView.dispatch(
            editorView.state.tr.replaceSelectionWith(schema.nodes.heading.create({ level: 4 }, link))
          )
        }
        editorView.focus()
      }, { once: true })
    },
    dom: findButton("button"),
    isActive: _state => false,
    isEnabled: state => canInsert(state, schema.nodes.heading)
  })

  const buttonH1 = new MenuButton({
    dom: findButton("h1"),
    exec(editorView) {
      toggleBlockType(this, editorView, schema.nodes.heading, { level: 1 })
    },
    isActive: state => hasActiveNodeType(state, schema.nodes.heading, { level: 1 }),
    isEnabled: state => canInsert(state, schema.nodes.image)
  })

  const buttonH2 = new MenuButton({
    dom: findButton("h2"),
    exec(editorView) {
      toggleBlockType(this, editorView, schema.nodes.heading, { level: 2 })
    },
    isActive: state => hasActiveNodeType(state, schema.nodes.heading, { level: 2 }),
    isEnabled: state => canInsert(state, schema.nodes.image)
  })

  const buttonH3 = new MenuButton({
    dom: findButton("h3"),
    exec(editorView) {
      toggleBlockType(this, editorView, schema.nodes.heading, { level: 3 })
    },
    isActive: state => hasActiveNodeType(state, schema.nodes.heading, { level: 3 }),
    isEnabled: state => canInsert(state, schema.nodes.image)
  })

  const buttonUl = new MenuButton({
    dom: findButton("ul"),
    command: wrapInList(schema.nodes.bullet_list),
    isEnabled: state => wrapInList(schema.nodes.bullet_list)(state)
  })

  const buttonOl = new MenuButton({
    dom: findButton("ol"),
    command: wrapInList(schema.nodes.ordered_list),
    isEnabled: state => wrapInList(schema.nodes.ordered_list)(state)
  })

  const buttonIndentIncrease = new MenuButton({
    dom: findButton("indent-increase"),
    command: sinkListItem(schema.nodes.list_item),
    isVisible: state => {
      return sinkListItem(schema.nodes.list_item)(state)
    }
  })

  const buttonIndentDecrease = new MenuButton({
    dom: findButton("indent-decrease"),
    command: liftListItem(schema.nodes.list_item),
    isVisible: state => {
      return liftListItem(schema.nodes.list_item)(state)
    }
  })

  const buttonLiquid = new MenuButton({
    exec: editorView => {
      let liquid
      if (hasActiveMark(editorView.state, schema.marks.liquid)) {
        const state = editorView.state
        const { doc, selection } = state
        doc.nodesBetween(selection.from, selection.to, (node, pos, parentNode, childIndex) => {
          if (node.marks && schema.marks.liquid.isInSet(node.marks)) {
            liquid = { text: node.textContent }

            const tr = state.tr
            tr.setSelection(TextSelection.create(tr.doc, pos, pos + node.nodeSize))
            editorView.dispatch(tr)
          }
        })
      }

      document.querySelector("[data-dialog-for=liquid]").dispatchEvent(new CustomEvent("x-show", { detail: {} }))

      window.addEventListener("update-liquid", e => {
        const liquid = e.detail
        if (!liquid.cancel && liquid.text) {
          const content = markdownParser
            .parse(liquid.text)
            .content.content[0].content.content

          const transaction = editorView.state.tr
          content.forEach(content => {
            transaction.replaceSelectionWith(content, false)
          })
          editorView.dispatch(transaction)
        }
        editorView.focus()
      }, { once: true })
    },
    dom: findButton("liquid"),
    isActive: state => hasActiveMark(state, schema.marks.liquid),
    isEnabled: state => canInsert(state, schema.nodes.text)
  })

  const buttonHr = new MenuButton({
    exec: editorView => {
      editorView.dispatch(editorView.state.tr.replaceSelectionWith(schema.nodes.horizontal_rule.create()))
      editorView.focus()
    },
    dom: findButton("hr"),
    isActive: _state => false,
    isEnabled: state => canInsert(state, schema.nodes.horizontal_rule)
  })

  const buttonTogglePreview = new MenuButton({
    dom: findButton("toggle-preview"),
    exec(_editorView) {
      this.dom.dispatchEvent(new Event("x-sync", { bubbles: true }))
      this.dom.dispatchEvent(new Event("x-toggle-preview", { bubbles: true }))
    }
  })

  return buildMenu([
    buttonBold,
    buttonItalic,
    buttonLink,
    buttonButton,
    buttonHr,
    buttonImage,
    buttonH1,
    buttonH2,
    buttonH3,
    buttonUl,
    buttonOl,
    buttonIndentIncrease,
    buttonIndentDecrease,
    buttonLiquid,
    buttonTogglePreview
  ])
}
