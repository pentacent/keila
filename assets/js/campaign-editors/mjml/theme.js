import { EditorView } from "@codemirror/view"

export default EditorView.theme(
  {
    "&": {
      color: "#f4f4f5",
      backgroundColor: "#030712"
    },
    ".cm-content": {
      caretColor: "#f9fafb"
    },
    "&.cm-focused .cm-cursor": {
      borderLeftColor: "#f9fafb"
    },
    "&.cm-focused .cm-selectionBackground, ::selection": {
      backgroundColor: "#083344 !important"
    },
    ".cm-selectionBackground, ::selection": {
      backgroundColor: "#083344"
    },
    ".cm-selectionMatch": {
      backgroundColor: "#155e75"
    },
    ".cm-gutters": {
      backgroundColor: "#111827",
      color: "#6b7280",
      border: "none"
    },
    ".ͼe": {
      color: "#93c5fd"
    },
    ".ͼi": {
      color: "#4ade80"
    }
  },
  { dark: true }
)
