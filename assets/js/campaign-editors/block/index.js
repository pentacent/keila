import EditorJS from "@editorjs/editorjs"
import Header from "@editorjs/header"
import List from "@editorjs/nested-list"
import Quote from "@editorjs/quote"
import Button from "./blocks/button"
import Image from "./blocks/image"
import Layout from "./blocks/layout"
import Separator from "./blocks/separator"

export default class BlockEditor {
  constructor(place, source) {
    const editor = new EditorJS({
      holder: place,
      placeholder: document.querySelector("#block-container-assets .editor-placeholder").innerText,
      data: JSON.parse(source.value),
      logLevel: "WARN",
      tools: {
        header: {
          class: Header,
          config: {
            levels: [1, 2, 3]
          }
        },
        layout: {
          class: Layout,
          config: {
            tools: {
              header: {
                class: Header,
                config: {
                  levels: [1, 2, 3]
                }
              },
              button: Button,
              image: {
                class: Image,
                inlineToolbar: true
              },
              quote: {
                class: Quote,
                inlineToolbar: true
              },
              list: {
                class: List,
                inlineToolbar: true
              },
              separator: Separator
            }
          }
        },
        button: Button,
        image: {
          class: Image,
          inlineToolbar: true
        },
        quote: {
          class: Quote,
          inlineToolbar: true
        },
        list: {
          class: List,
          inlineToolbar: true
        },
        separator: Separator
      },
      onChange() {
        window.setUnsavedReminder(true)
        editor.save().then((outputData) => {
          source.value = JSON.stringify(outputData)
          source.dispatchEvent(new Event("input", { bubbles: true }))
        }).catch((error) => {
          console.warn("Error saving editor content", error)
        })
      }
    })

    place.addEventListener("focusout", () => {
      editor.save().then((outputData) => {
        const value = JSON.stringify(outputData)
        if (source.value !== value) {
          source.value = value
          source.dispatchEvent(new Event("input", { bubbles: true }))
        }
      }).catch((error) => {
        console.warn("Error saving editor content", error)
      })
    })

    place.addEventListener("mouseleave", () => {
      editor.toolbar.close()
    })
  }
}
