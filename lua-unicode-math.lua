local mathfamattr = token.create'mathfamattr'
assert(mathfamattr.cmdname == 'assign_attr')
local attr = mathfamattr.index

local symlummain = token.create'symlummain'
assert(symlummain.cmdname == 'char_given')
local main_fam = symlummain.index

local prime_node_id = luatexbase.new_whatsit'prime'

local processed_families = {[main_fam] = true}

local parser = require'lua-uni-parse'
local mathclasses = parser.parse_file('MathClass-15', parser.eol + lpeg.Cg(parser.fields(parser.codepoint_range, lpeg.C(lpeg.S'NABCDFGLOPRSUVX'))), parser.multiset)

-- 1: Latin uppercase
-- 2: Latin lowercase
-- 3: Greek uppercase
-- 4: Greek lowercase
-- 5: Digits
-- 6: weird characters needing special handling
local char_types = {}

local pre_replacement = {
  [0x03F4] = 0x03A2,
  [0x2207] = 0x03AA,

  [0x2202] = 0x03CA,
  [0x03F5] = 0x03CB,
  [0x03D1] = 0x03CC,
  [0x03F0] = 0x03CD,
  [0x03D5] = 0x03CE,
  [0x03F1] = 0x03CF,
  [0x03D6] = 0x03D0,
}

local post_replacement = {
  [0x1D49D] = 0x212C,
  [0x1D4A0] = 0x2130,
  [0x1D4A1] = 0x2131,
  [0x1D4A3] = 0x210B,
  [0x1D4A4] = 0x2110,
  [0x1D4A7] = 0x2112,
  [0x1D4A8] = 0x2133,
  [0x1D4AD] = 0x211B,

  [0x1D506] = 0x212D,
  [0x1D50B] = 0x210C,
  [0x1D50C] = 0x2111,
  [0x1D515] = 0x211C,
  [0x1D51D] = 0x2128,

  [0x1D53A] = 0x2102,
  [0x1D53F] = 0x210D,
  [0x1D545] = 0x2115,
  [0x1D547] = 0x2119,
  [0x1D548] = 0x211A,
  [0x1D549] = 0x211D,
  [0x1D550] = 0x2124,

  [0x1D455] = 0x210E,

  [0x1D4BA] = 0x212F,
  [0x1D4BC] = 0x210A,
  [0x1D4C4] = 0x2134,
}

for i=0x41, 0x5A do
  char_types[i], char_types[i + 0x20] = 1, 2
end
char_types[0x0131] = 6
char_types[0x0237] = 6

for i=0x0391, 0x03A9 do
  char_types[i] = 3
end

for i=0x03B1, 0x03D0 do
  char_types[i] = 4
end
char_types[0x03DC] = 6
char_types[0x03DD] = 6

for i=0x0030, 0x0039 do
  char_types[i] = 5
end

for base, remapped in next, pre_replacement do
  -- We want to apply char_types before pre_replacement
  char_types[base], char_types[remapped] = char_types[remapped], nil
end

local remap_bases = {
  [0] = { -- Serif Normal
    0x0041, -- A
    0x0061, -- a
    0x0391, -- Α
    0x03B1, -- α
    0x0030, -- 0
  },
  [1] = { -- Serif Bold
    0x1D400, -- 𝐀
    0x1D41A, -- 𝐚
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7CE, -- 𝟎
  },
  [2] = { -- Serif Italic
    0x1D434, -- 𝐴
    0x1D44E, -- 𝑎
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [3] = { -- Serif Bold Italic
    0x1D468, -- 𝑨
    0x1D482, -- 𝒂
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [4] = { -- Sans Normal
    0x1D5A0, -- 𝖠
    0x1D5BA, -- 𝖺
    0x0391, -- Α
    0x03B1, -- α
    0x1D7E2, -- 𝟢
  },
  [5] = { -- Sans Bold
    0x1D5D4, -- 𝗔
    0x1D5EE, -- 𝗮
    0x1D756, -- 𝝖
    0x1D6C2, -- 𝛂
    0x1D7EC, -- 𝟬
  },
  [6] = { -- Sans Italic
    0x1D608, -- 𝘈
    0x1D622, -- 𝘢
    0x1D6E2, -- 𝛢
    0x1D770, -- 𝝰
    0x1D7E2, -- 𝟢
  },
  [7] = { -- Sans Bold Italic
    0x1D63C, -- 𝘼
    0x1D656, -- 𝙖
    0x1D790, -- 𝞐
    0x1D7AA, -- 𝞪
    0x1D7EC, -- 𝟬
  },
  [8] = { -- Script Normal
    0x1D49C, -- 𝒜
    0x1D4B6, -- 𝒶
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [9] = { -- Script Bold
    0x1D4D0, -- 𝓐
    0x1D4EA, -- 𝓪
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [12] = { -- Fraktur Normal
    0x1D504, -- 𝔄
    0x1D51E, -- 𝔞
    0x0391, -- Α
    0x03B1, -- α
    0x0030, -- 0
  },
  [13] = { -- Fraktur Bold
    0x1D56C, -- 𝕬
    0x1D586, -- 𝖆
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7CE, -- 𝟎
  },
  [16] = { -- Mono Normal
    0x1D670, -- 𝙰
    0x1D68A, -- 𝚊
    0x0391, -- Α
    0x03B1, -- α
    0x1D7F6, -- 𝟶
  },
  [20] = { -- Double-struck
    0x1D538, -- 𝔸
    0x1D552, -- 𝕒
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7D8, -- 𝟘
  },
}
local base = remap_bases[0]
remap_bases[0] = {} -- We don't want to overwrite it in the next step
for k, v in next, remap_bases do
  v[1] = v[1] and v[1] ~= base[1] and v[1] - base[1] or nil
  v[2] = v[2] and v[2] ~= base[2] and v[2] - base[2] or nil
  v[3] = v[3] and v[3] ~= base[3] and v[3] - base[3] or nil
  v[4] = v[4] and v[4] ~= base[4] and v[4] - base[4] or nil
  v[5] = v[5] and v[5] ~= base[5] and v[5] - base[5] or nil
end
remap_bases[false] = remap_bases[0] -- We don't want to overwrite it in the next step


local classcodes = {
  N = 0, -- Normal --> ord
  A = 7, -- Alphabetic --> variable
  B = 2, -- Binary --> bin
  C = 5, -- Closing --> close
  D = nil, -- Diacritic --> ???
  F = 0, -- Fence --> ???
  G = nil, -- Glyph part --> ???
  L = 1, -- Large --> op
  O = 4, -- Opening --> open
  P = 6, -- Punctuation --> punct
  R = 3, -- Relation --> rel
  S = nil, -- Space --> ???
  U = 0, -- Unary --> ord
  V = 2, -- Vary --> bin
  X = nil, -- Special --> ???
}

local delimiterclasses = {
  O = true,
  F = true,
  C = true,
}

local setmathcode = tex.setmathcode
for cp, class in pairs(mathclasses) do
  local classcode = classcodes[class]
  if classcode then
    tex.setmathcode(cp, classcode, main_fam, cp)
    if delimiterclasses[class] then
      tex.setdelcode(cp, main_fam, cp, 0, 0)
    end
  elseif class == 'G' or class == 'S' then
    -- Ignored
  else
    -- print(string.format("U+%04X (%s): %s", cp, utf8.char(cp), class))
  end
end

local math_char_t = node.id'math_char'
local sub_mlist_t = node.id'sub_mlist'
-- local sub_box_t = node.id'sub_box'

local traverse_list

-- container is set if we are a nucleus
local function traverse_kernel(n, container)
  if not n then return 0, container end
  local id = n.id
  if id == math_char_t then
    local fam, char = n.fam, n.char
    if processed_families[fam] then
      local char_type = char_types[char]
      if char_type then
        char = pre_replacement[char] or char
        local offset = remap_bases[node.get_attribute(n, attr) or false][char_type]
        if offset then
          char = char + offset
          n.char = post_replacement[char] or char
        end
      end
    end
  elseif id == sub_mlist_t then
    return traverse_list(n.head, container)
  -- elseif id == sub_box_t then
  end
  return 0, container
end

local noad_t = node.id'noad'
local accent_t = node.id'accent'
local choice_t = node.id'choice'
local radical_t = node.id'radical'
local fraction_t = node.id'fraction'
-- local fence_t = node.id'fence'

local whatsit_t = node.id'whatsit'
local user_defined_s = node.subtype'user_defined'

local process_prime_node

-- parent is only set if we are a nucleus sub_mlist
function traverse_list(head, parent)
  local next_node, state, n = node.traverse(head)
  while true do
    local id, sub
    n, id, sub = next_node(state, n)
    if n == nil then break end
  -- end
  -- for n, id, sub in node.traverse(head) do
    local levels = 0
    if id == noad_t then
      traverse_kernel(n.sub)
      traverse_kernel(n.sup)
      levels, n = traverse_kernel(n.nucleus, n, parent)
    elseif id == accent_t then
      traverse_kernel(n.sub)
      traverse_kernel(n.sup)
      traverse_kernel(n.accent)
      traverse_kernel(n.bot_accent)
      levels, n = traverse_kernel(n.nucleus, n, parent)
    elseif id == choice_t then
      traverse_list(n.display)
      traverse_list(n.text)
      traverse_list(n.script)
      traverse_list(n.scriptscript)
    elseif id == radical_t then
      traverse_kernel(n.sub)
      traverse_kernel(n.sup)
      traverse_kernel(n.degree)
      -- traverse_delim(n.left)
      levels, n = traverse_kernel(n.nucleus, n, parent)
    elseif id == fraction_t then
      traverse_kernel(n.num)
      traverse_kernel(n.denom)
      -- traverse_delim(n.left)
      -- traverse_delim(n.middle)
      -- traverse_delim(n.right)
    -- elseif id == fence_t then
      -- traverse_delim(n.delim)
    elseif id == whatsit_t and sub == user_defined_s then
      local user_id = n.user_id
      if user_id == prime_node_id then
        levels, n = process_prime_node(n, parent)
      end
    end
    if levels ~= 0 then return levels - 1, n end
  end
  return 0, parent
end

luatexbase.add_to_callback('pre_mlist_to_hlist_filter', function(n, style, penalties)
  traverse_list(n)
  return true
end, 'lua-unicode-math')

tex.setmathcode(0x2D, tex.getmathcodes(0x2212)) -- '-' get the mathcode of '−'

local func = luatexbase.new_luafunction'prime_helper:w'
token.set_lua("prime_helper:w", func, 'protected')
local nest = tex.nest
local mmode = 267

lua.get_functions_table()[func] = function()
  local top = nest.top
  local mode = top.mode
  if mode ~= mmode and mode ~= -mmode then
    return tex.error'Math mode required'
  end
  local n = node.new(whatsit_t, user_defined_s)
  n.user_id, n.type, n.value = prime_node_id, 100, token.scan_int()
  node.insert_after(top.head, top.tail, n)
  top.tail = n
end

local prime_lookup = {
  [0x2032] = {
    [0x2032] = 0x2033,
    [0x2033] = 0x2034,
  },
  [0x2035] = {
    [0x2035] = 0x2036,
    [0x2036] = 0x2037,
  },
}

function process_prime_node(n, parent)
  assert(parent)
  local char = n.value
  local pre_sup, pre_sub
  local prev = parent.prev
  local prev_id = prev and prev.id
  if prev_id == noad_t or prev_id == accent_t or prev_id == radical_t then
    pre_sup, pre_sub = prev.sup, prev.sub
  else
    node.flush_list(parent.nucleus.head)
    parent.nucleus.head = nil
    prev = parent
  end
  if pre_sub == nil then
    prev.sub, parent.sub = parent.sub, nil
  elseif parent.sub then
    tex.error'Double subscript ignored'
  end
  local post_sup = parent.sup

  -- First check for the cases where no sub_mlist is needed:
  local done
  if post_sup == nil then
    if pre_sup == nil then
      local new_sup = node.new(math_char_t)
      new_sup.fam, new_sup.char = main_fam, char
      prev.sup = new_sup

      done = true
    elseif pre_sup.id == math_char_t and pre_sup.fam == main_fam and prime_lookup[char][pre_sup.char] then
      pre_sup.char = prime_lookup[char][pre_sup.char]

      done = true
    end
  end

  if not done then
    local mlist -- Some sub_mlist node which will become the new sup
    local new_head, current_tail

    if pre_sup ~= nil then
      if pre_sup.id == sub_mlist then
        mlist, new_head = pre_sup, pre_sup.head
        current_tail = node.tail(head)
      else
        -- mlist = node.new(sub_mlist_t)
        new_head = node.new(noad_t, 0)
        -- mlist.head = noad
        new_head.nucleus = pre_sup
        current_tail = new_head
      end
    end

    if current_tail and current_tail.id == noad_t then
      local nucleus = current_tail.nucleus
      if nucleus.id == math_char_t and nucleus.fam == main_fam then
        local oldchar = nucleus.char
        local nextchar = prime_lookup[char][oldchar]
        if nextchar then
          nucleus.char, done = nextchar, true
        end
      end
    end
    
    if not done then
      local noad = node.new(noad_t, 0)
      local nucleus = node.new(math_char_t)
      nucleus.fam, nucleus.char = main_fam, char
      noad.nucleus = nucleus
      new_head, current_tail = node.insert_after(new_head, current_tail, noad)
    end

    if post_sup ~= nil then
      if post_sup.id == sub_mlist then
        local post_head = post_sup.head
        current_tail.next, post_head.prev = post_head, current_tail

        if mlist then
          post_sup.head = nil
        else
          mlist = post_head
          parent.sup = nil
        end
      else
        -- mlist = node.new(sub_mlist_t)
        local noad = node.node(noad_t, 0)
        -- mlist.head = noad
        noad.nucleus = post_sup
        parent.sup = nil
        node.insert_after(new_head, current_tail, noad)
      end
    end

    if not mlist then
      mlist = node.new(sub_mlist_t)
    end

    mlist.head = new_head
    prev.sup = mlist
    print(mlist)
  end

  if parent ~= prev then
    node.remove(prev, parent)
    node.free(parent)
  end
  return 1, prev
end
