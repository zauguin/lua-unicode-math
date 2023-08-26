local function sub_style(s) return (s >> 1) | 5 end
local function sup_style(s) return ((s & 4) >> 1) | (s & 1) | 4 end
local function num_style(s) return s + 2 - s//6 * 2 end
local function denom_style(s) return (s | 1) + 2 - s//6 * 2 end

local style_names = {
  [0] = 'display',
  [1] = 'crampeddisplay',
  [2] = 'text',
  [3] = 'crampedtext',
  [4] = 'script',
  [5] = 'crampedscript',
  [6] = 'scriptscript',
  [7] = 'crampedscriptscript',
}
local reverse_styles = {}
for i=0, 7 do
  reverse_styles[style_names[i]] = i
end

local mathfamattr = token.create'mathfamattr'
assert(mathfamattr.cmdname == 'assign_attr')
local attr = mathfamattr.index

local symlummain = token.create'symlummain'
assert(symlummain.cmdname == 'char_given')
local main_fam = symlummain.index

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

local serif, sans, script, fraktur, mono, bb = 0, 4, 8, 12, 16, 20
local bold, italic = 1, 2

local remap_bases = {
  [serif] = { -- Serif Normal
    0x0041, -- A
    0x0061, -- a
    0x0391, -- Α
    0x03B1, -- α
    0x0030, -- 0
  },
  [serif | bold] = { -- Serif Bold
    0x1D400, -- 𝐀
    0x1D41A, -- 𝐚
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7CE, -- 𝟎
  },
  [serif | italic] = { -- Serif Italic
    0x1D434, -- 𝐴
    0x1D44E, -- 𝑎
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [serif | bold | italic] = { -- Serif Bold Italic
    0x1D468, -- 𝑨
    0x1D482, -- 𝒂
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [sans] = { -- Sans Normal
    0x1D5A0, -- 𝖠
    0x1D5BA, -- 𝖺
    0x0391, -- Α
    0x03B1, -- α
    0x1D7E2, -- 𝟢
  },
  [sans | bold] = { -- Sans Bold
    0x1D5D4, -- 𝗔
    0x1D5EE, -- 𝗮
    0x1D756, -- 𝝖
    0x1D6C2, -- 𝛂
    0x1D7EC, -- 𝟬
  },
  [sans | italic] = { -- Sans Italic
    0x1D608, -- 𝘈
    0x1D622, -- 𝘢
    0x1D6E2, -- 𝛢
    0x1D770, -- 𝝰
    0x1D7E2, -- 𝟢
  },
  [sans | bold | italic] = { -- Sans Bold Italic
    0x1D63C, -- 𝘼
    0x1D656, -- 𝙖
    0x1D790, -- 𝞐
    0x1D7AA, -- 𝞪
    0x1D7EC, -- 𝟬
  },
  [script] = { -- Script Normal
    0x1D49C, -- 𝒜
    0x1D4B6, -- 𝒶
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [script | bold] = { -- Script Bold
    0x1D4D0, -- 𝓐
    0x1D4EA, -- 𝓪
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [fraktur] = { -- Fraktur Normal
    0x1D504, -- 𝔄
    0x1D51E, -- 𝔞
    0x0391, -- Α
    0x03B1, -- α
    0x0030, -- 0
  },
  [fraktur | bold] = { -- Fraktur Bold
    0x1D56C, -- 𝕬
    0x1D586, -- 𝖆
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7CE, -- 𝟎
  },
  [mono] = { -- Mono Normal
    0x1D670, -- 𝙰
    0x1D68A, -- 𝚊
    0x0391, -- Α
    0x03B1, -- α
    0x1D7F6, -- 𝟶
  },
  [bb] = { -- Double-struck
    0x1D538, -- 𝔸
    0x1D552, -- 𝕒
    0x1D6A8, -- 𝚨
    0x1D6C2, -- 𝛂
    0x1D7D8, -- 𝟘
  },
}
remap_bases[false] = { -- Default
  remap_bases[serif | italic][1], -- Latin uppercase
  remap_bases[serif | italic][2], -- Latin lowercase
  remap_bases[serif][3], -- Greek uppercase
  remap_bases[serif | italic][4], -- Greek lowercase
  remap_bases[serif][5], -- Serif digits
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
local whatsit_t = node.id'whatsit'
local user_defined_s = node.subtype'user_defined'

-- Map from whatsit user_ids to handlers
-- Handler return values: head, node, state
local math_whatsit_processors = {}

local traverse_list

-- container is set if we are a nucleus
local function traverse_kernel(style, n, outer_head, outer)
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
    n.head = traverse_list(style, n.head)
  elseif id == whatsit_t and n.subtype == user_defined_s then
    local user_id = n.user_id
    local processor = math_whatsit_processors[user_id]
    if processor then
      return processor(style, n, outer_head, outer)
    end
  end
  return outer_head, outer
end

local noad_t = node.id'noad'
local accent_t = node.id'accent'
local choice_t = node.id'choice'
local style_t = node.id'style'
local radical_t = node.id'radical'
local fraction_t = node.id'fraction'
-- local fence_t = node.id'fence'

-- parent is only set if we are a nucleus sub_mlist
function traverse_list(style, head)
  local next_node, state, n = node.traverse(head)
  while true do
    local id, sub
    n, id, sub = next_node(state, n)
    if n == nil then break end
  -- end
  -- for n, id, sub in node.traverse(head) do
    if id == noad_t then
      traverse_kernel(sub_style(style), n.sub)
      traverse_kernel(sup_style(style), n.sup)
      head, n, state = traverse_kernel(style, n.nucleus, head, n)
    elseif id == accent_t then
      traverse_kernel(sub_style(style), n.sub)
      traverse_kernel(sup_style(style), n.sup)
      traverse_kernel(style, n.accent)
      traverse_kernel(style, n.bot_accent)
      head, n, state = traverse_kernel(style | 1, n.nucleus, head, n)
    elseif id == choice_t then
      n.display = traverse_list(0, n.display)
      n.text = traverse_list(2, n.text)
      n.script = traverse_list(4, n.script)
      n.scriptscript = traverse_list(6, n.scriptscript)
    elseif id == style_t then
      style = reverse_styles[n.style]
    elseif id == radical_t then
      traverse_kernel(sub_style(style), n.sub)
      traverse_kernel(sup_style(style), n.sup)
      traverse_kernel(6, n.degree)
      if sub < 3 or sub >= 6 then -- radicals and roots, \Udelimiterover, \Uhextension
        head, n, state = traverse_kernel(style | 1, n.nucleus, head, n)
      elseif sub == 3 then -- \Uunderdelimiter
        head, n, state = traverse_kernel(sub_style(style), n.nucleus, head, n)
      elseif sub == 4 then -- \Uoverdelimiter
        head, n, state = traverse_kernel(sup_style(style), n.nucleus, head, n)
      elseif sub == 5 then -- \Udelimiterunder
        head, n, state = traverse_kernel(style, n.nucleus, head, n)
      end
      -- traverse_delim(n.left)
    elseif id == fraction_t then
      traverse_kernel(num_style(style), n.num)
      traverse_kernel(denom_style(style), n.denom)
      -- traverse_delim(n.left)
      -- traverse_delim(n.middle)
      -- traverse_delim(n.right)
    -- elseif id == fence_t then
      -- traverse_delim(n.delim)
    elseif id == whatsit_t and sub == user_defined_s then
      local user_id = n.user_id
      local processor = math_whatsit_processors[user_id]
      if processor then
        head, n, state = processor(style, n, head)
      end
    end
  end
  return head
end

luatexbase.add_to_callback('pre_mlist_to_hlist_filter', function(n, style, penalties)
  return traverse_list(reverse_styles[style], n)
end, 'lua-unicode-math')

tex.setmathcode(0x2D, tex.getmathcodes(0x2212)) -- '-' gets the mathcode of '−'

local nest = tex.nest

local mmode do
  for k, v in next, tex.getmodevalues() do
    if v == 'math' then
      mmode = k
      break
    end
  end
  assert(mmode)
end

local Ustartmath = token.new(text_style, token.command_id'math_shift_cs')
local lua_call = token.command_id'lua_call'
local environment = setmetatable({
  check_math = function(id)
    local mode = nest.top.mode
    if mode ~= mmode and mode ~= -mmode then
      token.push_back(Ustartmath, token.new(id, lua_call))
      return tex.error('Missing $ inserted', {
        "I've inserted a begin-math/end-math symbol since I think",
        "you left one out. Proceed, with fingers crossed."
      })
    end
  end,
  math_whatsit_processors = math_whatsit_processors,
  main_fam = main_fam,
  write_whatsit = function(user_id, kind, value)
    local n = node.new(whatsit_t, user_defined_s)
    n.user_id, n.type, n.value = user_id, kind, value
    node.write(n)
  end,
  write_whatsit_wrapped = function(user_id, kind, value, noad_sub)
    local n = node.new(noad_t, noad_sub)
    local nuc = node.new(whatsit_t, user_defined_s)
    n.nucleus = nuc
    nuc.user_id, nuc.type, nuc.value = user_id, kind, value
    node.write(n)
  end,
}, { __index = _ENV })

for _, name in ipairs{'prime', 'not'} do
  loadfile(kpse.find_file(string.format('lua-unicode-math--%s', name), 'lua'), 'bt', environment)()
end
