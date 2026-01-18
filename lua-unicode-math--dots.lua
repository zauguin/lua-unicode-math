local dots_node_id = luatexbase.new_whatsit'dots'

local func = luatexbase.new_luafunction'dots'
token.set_lua("mdots@", func, 'protected')

lua.get_functions_table()[func] = function(id)
  check_math(id)
  write_whatsit_wrapped(dots_node_id, 100, 0, 9)
end

local accent_t = node.id'accent'
local math_char_t = node.id'math_char'
local sub_mlist_t = node.id'sub_mlist'
local whatsit_t = node.id'whatsit'
local noad_t = node.id'noad'
local radical_t = node.id'radical'
local user_defined_sub = node.subtype'user_defined'

local cp = utf8.codepoint

local comma_cp = cp','
local ldots = cp'…'
local cdots = cp'⋯'
local binary_dots = cdots
local comma_dots = ldots
local int_dots = cdots
local other_dots = ldots
local lookup = {
  -- [cp'']
}

local function select_dots_from_next(noad)
  -- FIXME: Handle \boldsymbol. See \boldsymboldots@
  if not noad or noad.id ~= noad_t then return other_dots end
  local sub = noad.subtype
  if sub == 4 or sub == 5 then -- bin or rel
    return binary_dots
  end
  local nucleus = noad.nucleus
  local id = nucleus.id
  if id == math_char_t then
    local cp = nucleus.char
    if cp == comma_cp then
      return comma_dots
    end
    if nucleus.char == comma_cp then return comma_dots end
  elseif id == whatsit_t and nucleus.subtype == user_defined_sub then
    if nucleus.user_id == not_whatsit then
      return binary_dots
    end
    -- TODO: Consider: How to handle another \dots
  end
  return other_dots
end

math_whatsit_processors[dots_node_id] = function(_style, n, parent_head, parent)
  assert(parent)
  -- local char = n.value
  local pre_sup, pre_sub
  local after = parent.next

  local dots_cp = select_dots_from_next(after)

  node.free(n)
  local char_node = node.new(math_char_t)
  char_node.attr, char_node.fam, char_node.char = n.attr, main_fam, dots_cp
  parent.nucleus = char_node
  return parent_head, parent
end

local func = luatexbase.new_luafunction'__l_uni_math_set_previous_dots_type:w'
token.set_lua("__l_uni_math_set_previous_dots_type:w", func, 'protected')

lua.get_functions_table()[func] = function(id)
  local cp = token.scan_int()
  local top_nest = tex.nest.top
  local tail = top_nest.tail
  if tail.id ~= noad_t then return end
  local nucleus = tail.nucleus
  if (nucleus and nucleus.id) ~= whatsit_t then return end
  if nucleus.subtype ~= user_defined_sub then return end
  if nucleus.user_id ~= dots_node_id then return end
  local char_node = node.new(math_char_t)
  char_node.attr, char_node.fam, char_node.char = nucleus.attr, main_fam, cp
  node.free(nucleus)
  tail.nucleus = char_node
end
