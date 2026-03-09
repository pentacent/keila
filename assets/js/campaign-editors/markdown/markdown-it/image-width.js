/**
 * Process inline attribute lists (IAL) for image tags:
 * ![alt text](https://example.com/image.jpg){: width=123}
 *
 * NOTE: If more IAL attributes should be supported in the future, this
 * plugin should be refactored and made configurable.
 */

export function markdownItImageWidth(md) {
  md.core.ruler.after("inline", "image_width", function(state) {
    for (const blockToken of state.tokens) {
      if (blockToken.type !== "inline" || !blockToken.children) continue

      const children = blockToken.children
      const newChildren = []

      for (let i = 0; i < children.length; i++) {
        const token = children[i]
        newChildren.push(token)

        // Check if this is an image token followed by a text token with IAL
        if (token.type === "image" && i + 1 < children.length) {
          const next = children[i + 1]
          if (next.type === "text") {
            const match = next.content.match(/^\{:\s*width=(\d+)\s*\}/)
            if (match) {
              const width = match[1]

              // Add width attribute to the image token
              if (!token.attrs) token.attrs = []
              token.attrs.push(["width", width])

              // Remove the matched IAL from the text content
              const remaining = next.content.slice(match[0].length)
              if (remaining) {
                next.content = remaining
              } else {
                // Skip the text token entirely
                i++
              }
            }
          }
        }
      }

      blockToken.children = newChildren
    }
  })
}
