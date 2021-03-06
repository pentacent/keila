import { setBlockType } from "prosemirror-commands"
import { schema } from "prosemirror-markdown"

/** Toggles a DOM class. This function operates on plain DOM, not ProseMirror. */
export function toggleClass(dom, className, enabled) {
    if (enabled) {
        const classNames = dom.className.split(" ")
        if (!classNames.find(name => name == classNames)) {
            dom.className = dom.className + " " + className
        }
    } else {
        dom.className = dom.className.split(" ").filter(name => name != className).join(" ")
    }
}

/**
 * Toggle ProseMirror node types for selected text blocks.
 * Reverts to paragraph type if type is already active.
 * 
 * @param {*} item - MenuButton
 * @param {*} editorView - ProseMirror EditorView
 * @param {*} nodeType - Schema node type
 * @param {*} attrs - Schema node attrs
 */
export function toggleBlockType(item, editorView, nodeType, attrs) {
    if (item.isActive(editorView.state)) {
        setBlockType(schema.nodes.paragraph)(editorView.state, editorView.dispatch)
    } else {
        setBlockType(nodeType, attrs)(editorView.state, editorView.dispatch)
    }
    editorView.focus()
}

/**
 * Returns whether given mark is active in current selection.
 * 
 * @param {*} state - ProseMirror EditorState
 * @param {*} mark - Schema mark
 * @returns {boolean}
 */
export function hasActiveMark(state, mark) {
    let { from, $from, to, empty } = state.selection
    if (empty) return mark.isInSet(state.storedMarks || $from.marks())
    else return state.doc.rangeHasMark(from, to, mark)
}

/**
 * Returns whether given node type is active in current selection.
 * 
 * @param {*} state - ProseMirror EditorState
 * @param {*} nodeType - Schema node type
 * @param {*} attrs - Schema node type attrs
 * @returns 
 */
export function hasActiveNodeType(state, nodeType, attrs) {
    let { $from, to, node } = state.selection
    if (node) return node.hasMarkup(nodeType, attrs)
    return to <= $from.end() && $from.parent.hasMarkup(nodeType, attrs)
}

/**
 * Returns whether given `nodeType` can be inserted at current selection.
 * 
 * @param {*} state - ProseMirror EditorState
 * @param {*} nodeType - Schema node type
 * @returns {boolean}
 */
export function canInsert(state, nodeType) {
    let $from = state.selection.$from
    for (let d = $from.depth; d >= 0; d--) {
        let index = $from.index(d)
        if ($from.node(d).canReplaceWith(index, index, nodeType)) return true
    }
    return false
}
