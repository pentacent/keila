import { schema } from "./markdown-schema"
import { InputRule } from 'prosemirror-inputrules'

/**
 * Build an input rule for automatically marking a string when a given
 * pattern is typed.
 *
 * References:
 * https://github.com/benrbray/prosemirror-math/blob/master/src/plugins/math-inputrules.ts
 * https://github.com/ProseMirror/prosemirror-inputrules/blob/master/src/rulebuilders.js
 */
export function markingInputRule(
  pattern,
  markType
) {
  return new InputRule(
    pattern,
    (state, match, start, end) => {
        const content = [schema.text(match[1], [markType.create()])]
        if (match[2]) {
            content.push(schema.text(match[2]))
        }

        return state.tr
        .replaceRangeWith(start, end, content)
        // .removeStoredMark(markType)
    }
  )
}
