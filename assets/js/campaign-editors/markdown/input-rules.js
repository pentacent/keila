import { inputRules, textblockTypeInputRule, wrappingInputRule } from "prosemirror-inputrules"
import { markingInputRule } from "./input-rule-mark"
import { schema } from "./markdown-schema"

const rules = inputRules({
  rules: [
    markingInputRule(/(\{\{.*\}\})$/, schema.marks.liquid),
    markingInputRule(/\*\*(.*)\*\*(.)$/, schema.marks.strong),
    markingInputRule(/\*([^*]+)\*([^*])$/, schema.marks.em),
    markingInputRule(/^\s*(\{%.*%\})$/, schema.marks.liquid),
    wrappingInputRule(/^\s*>\s$/, schema.nodes.blockquote),
    wrappingInputRule(/^\s*(-|\*|\+)\s$/, schema.nodes.bullet_list),
    textblockTypeInputRule(/^\s*\#\s$/, schema.nodes.heading, { level: 1 }),
    textblockTypeInputRule(/^\s*\#\#\s$/, schema.nodes.heading, { level: 2 }),
    textblockTypeInputRule(/^\s*\#\#\#\s$/, schema.nodes.heading, { level: 3 })
  ]
})

export { rules as inputRules }
