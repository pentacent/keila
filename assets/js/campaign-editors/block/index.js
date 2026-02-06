import EditorJS from "@editorjs/editorjs"
import Header from "@editorjs/header"
import List from "@editorjs/nested-list"
import Quote from "@editorjs/quote"
import Button from "./blocks/button"
import Image from "./blocks/image"
import Layout from "./blocks/layout"
import Separator from "./blocks/separator"
import SocialIcons from "./blocks/social-icons"
import Alignment from "./tools/alignment"
import TextColor from "./tools/text-color"
import AlignmentTune from "./tunes/alignment"

export default class BlockEditor {
  constructor(place, source) {
    const editor = new EditorJS({
      holder: place,
      placeholder: document.querySelector("#block-container-assets .editor-placeholder").innerText,
      data: JSON.parse(source.value),
      logLevel: "WARN",
      tools: {
        textColor: {
          class: TextColor
        },
        alignment: {
          class: AlignmentTune
        },
        alignmentInline: {
          class: Alignment
        },
        header: {
          class: Header,
          inlineToolbar: true,
          config: {
            levels: [1, 2, 2]
          },
          tunes: ["alignment"]
        },
        paragraph: {
          tunes: ["alignment"]
        },
        layout: {
          class: Layout,
          config: {
            tools: {
              alignment: {
                class: AlignmentTune
              },
              alignmentInline: {
                class: Alignment
              },
              header: {
                class: Header,
                inlineToolbar: true,
                config: {
                  levels: [1, 2, 3]
                },
                tunes: ["alignment"]
              },
              paragraph: {
                tunes: ["alignment"]
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
              socialIcons: SocialIcons,
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
        separator: Separator,
        socialIcons: SocialIcons
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

    // NOTE: This variable keeps track of whether
    // we've manually opened or closed the toolbar.
    // This is necessary because the API doesn't expose
    // the toolbar state
    let maybeOpen = false

    place.addEventListener("mouseleave", () => {
      editor.toolbar.close()
      maybeOpen = false
    })

    place.addEventListener("mouseenter", () => {
      if (!maybeOpen) editor.toolbar.open()
      maybeOpen = true
    })
  }
}
