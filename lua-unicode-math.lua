local function sub_style(s) return (s >> 1) | 5 end
local function sup_style(s) return ((s & 4) >> 1) | (s & 1) | 4 end
local function num_style(s) return s + 2 - s//6 * 2 end
local function denom_style(s) return (s | 1) + 2 - s//6 * 2 end

local unset_attribute = -0x7FFFFFFF

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

local leftroot_attr = luatexbase.new_attribute'leftroot'
local uproot_attr = luatexbase.new_attribute'uproot'

local symlummain = token.create'symlummain'
assert(symlummain.cmdname == 'char_given')
local main_fam = symlummain.index

local processed_families = {[main_fam] = true}

local parser = require'lua-uni-parse'
local mathclasses = parser.parse_file('MathClass-15', parser.eol + lpeg.Cg(parser.fields(parser.codepoint_range, lpeg.C(lpeg.S'NABCDFGLOPRSUVX'))), parser.multiset)

-- Store all Lua tables that should be cleaned whenever the mathsetup get changed.
-- The tables are stored as keys, the values are ignored.
local mathsize_reset_maps = setmetatable({}, {__mode = 'k'})

-- Generate a table that is queried by (fam << 2) | (style >> 1) and provides
-- get_data(font.getfont(fid)) for fid matching the font at fam/style while
-- aggressively caching everything involved.
local function family_style_fontdir_map(get_data, default)
  -- The base is a metatable based cache on fontids. This is stable since fontids never change.
  local font_cache = setmetatable({}, {__index = function(t, fid)
    local fontdir = font.getfont(fid)
    if not fontdir then return default end
    local data = get_data(fontdir)
    if data == nil then
      data = default
    end
    t[fid] = data
    return data
  end})
  local fam_cache = setmetatable({}, {__index = function(t, mathfont_locator)
    local fam = mathfont_locator >> 2
    local size = mathfont_locator & 3
    if size ~= 0 then
      size = size - 1
    end
    local fid = node.family_font(fam, size)
    if fid == 0 then return default end
    local data = font_cache[fid]
    t[mathfont_locator] = data
    return data
  end})
  mathsize_reset_maps[fam_cache] = true
  return fam_cache
end

local vs_maps = setmetatable({}, {__index = function(t, vs)
  local map = family_style_fontdir_map(function(fontdir)
    local resources = fontdir.resources
    local variants = resources and resources.variants
    return variants and variants[vs]
  end, {})
  t[vs] = map
  return map
end})

-- We derive mathclasses from the Unicode data file MathClass-15.txt, but some characters can be used
-- in different ways in math and LaTeX traditionally defines a different class for them by default than
-- Unicode does. For these we adjust the class here.
mathclasses[0x2F] = 'N' -- /
mathclasses[0x5C] = 'N' -- \
mathclasses[0x22EF] = 'N' -- ⋯
mathclasses[0x2E] = 'N' -- .

-- Integrals and other big operators have the same classes in data files, but we need to tell them apart.
-- Therefore we have a fixed list of all integral like codepoints here.
local integral_codepoints = {
  [0x222B] = true, -- ∫
  [0x222C] = true, -- ∬
  [0x222D] = true, -- ∭
  [0x222E] = true, -- ∮
  [0x222F] = true, -- ∯
  [0x2230] = true, -- ∰
  [0x2231] = true, -- ∱
  [0x2232] = true, -- ∲
  [0x2233] = true, -- ∳
  [0x2A0B] = true, -- ⨋
  [0x2A0C] = true, -- ⨌
  [0x2A0D] = true, -- ⨍
  [0x2A0E] = true, -- ⨎
  [0x2A0F] = true, -- ⨏
  [0x2A10] = true, -- ⨐
  [0x2A11] = true, -- ⨑
  [0x2A12] = true, -- ⨒
  [0x2A13] = true, -- ⨓
  [0x2A14] = true, -- ⨔
  [0x2A15] = true, -- ⨕
  [0x2A16] = true, -- ⨖
  [0x2A17] = true, -- ⨗
  [0x2A18] = true, -- ⨘
  [0x2A19] = true, -- ⨙
  [0x2A1A] = true, -- ⨚
  [0x2A1B] = true, -- ⨛
  [0x2A1C] = true, -- ⨜
}

-- Generally mathematical alphabets in Unicode are sequential blocks which reflect the order of the corresponding non-mathematical characters.
-- Therefore we can just store the position of the base characters for each style and then access other characters as offsets.
--
-- There are a few exceptions though:
-- For some greek character, the non-mathematical alphabet has some characters in positions not matching the mathematical alphabets.
-- This typically happens for variant forms where the non-mathematical slot is occupied by some pre-composed accented glyph.
-- These we map before processing to be in the position we expect them to be in.
--
-- Special mention:
-- U+0131 (dotless i), U+0237 (dotless j), U+03DC (capital digamma), and U+03DD (small digamma)
-- These four need to remapped in some styles but don't fit the general alphabets at all.
-- There are no expected locations to map them into, so we remap them completely outside the normal
-- Unicode range and then map the adjusted versions back.
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

  [0x0131] = 0x100000,
  [0x0237] = 0x100001,
  [0x03DC] = 0x100002,
  [0x03DD] = 0x100003,
}

-- More common is the opposite case: Some mathematical characters are not in the spaces normally associated with their alphabets but much lower.
-- This happens when the corresponding character was already encoded by the time the remaining alphabet got added.
-- We remap after processing from their expected to their actual places.
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
  [0x1D551] = 0x2124,

  [0x1D455] = 0x210E,

  [0x1D4BA] = 0x212F,
  [0x1D4BC] = 0x210A,
  [0x1D4C4] = 0x2134,

  -- dotless i -- only italic variant exists
  [0x11D3B9] = 0x0131, -- bfup
  [0x11D3ED] = 0x1D6A4, -- it
  [0x11D421] = 0x1D6A4, -- bfit
  [0x11D559] = 0x0131, -- sfup
  [0x11D58D] = 0x0131, -- sfit
  [0x11D5C1] = 0x1D6A4, -- bfsfup
  [0x11D5F5] = 0x1D6A4, -- bfsfit
  [0x11D455] = 0x1D6A4, -- cal
  [0x11D489] = 0x1D6A4, -- bfcal
  [0x11D4BD] = 0x0131, -- frak
  [0x11D525] = 0x0131, -- bffrak
  [0x11D629] = 0x0131, -- tt
  [0x11D4F1] = 0x0131, -- bb

  -- dotless j -- only italic variant exists
  [0x11D3BA] = 0x0237, -- bfup
  [0x11D3EE] = 0x1D6A5, -- it
  [0x11D422] = 0x1D6A5, -- bfit
  [0x11D55A] = 0x0237, -- sfup
  [0x11D58E] = 0x0237, -- sfit
  [0x11D5C2] = 0x1D6A5, -- bfsfup
  [0x11D5F6] = 0x1D6A5, -- bfsfit
  [0x11D456] = 0x1D6A5, -- cal
  [0x11D48A] = 0x1D6A5, -- bfcal
  [0x11D4BE] = 0x0237, -- frak
  [0x11D526] = 0x0237, -- bffrak
  [0x11D62A] = 0x0237, -- tt
  [0x11D4F2] = 0x0237, -- bb

  -- capital digamma -- only bold variant exists
  [0x11D319] = 0x1D7CA, -- bfup
  [0x11D353] = 0x03DC, -- it
  [0x11D38D] = 0x1D7CA, -- bfit
  [0x11D3C7] = 0x1D7CA, -- bfsfup
  [0x11D401] = 0x1D7CA, -- bfsfit

  -- small digamma -- only bold variant exists
  [0x11D314] = 0x1D7CB, -- bfup
  [0x11D34E] = 0x03DD, -- it
  [0x11D388] = 0x1D7CB, -- bfit
  [0x11D3C2] = 0x1D7CB, -- bfsfup
  [0x11D3FC] = 0x1D7CB, -- bfsfit
}

-- The characters come in 5 blocks
-- 1: Latin uppercase
-- 2: Latin lowercase
-- 3: Greek uppercase
-- 4: Greek lowercase
-- 5: Digits
local char_Latin = 1 -- Latin uppercase
local char_latin = 2 -- Latin lowercase
local char_Greek = 3 -- Greek uppercase
local char_greek = 4 -- Greek lowercase
local char_digit = 5 -- Digits
local char_types = {}

for i=0x41, 0x5A do
  char_types[i], char_types[i + 0x20] = char_Latin, char_latin
end

for i=0x0391, 0x03A9 do
  char_types[i] = char_Greek
end

for i=0x03B1, 0x03D0 do
  char_types[i] = char_greek
end

for i=0x0030, 0x0039 do
  char_types[i] = char_digit
end

for base, remapped in next, pre_replacement do
  -- We want to apply char_types before pre_replacement
  char_types[base], char_types[remapped] = char_types[remapped], nil
end
char_types[0x0131] = char_latin -- ı -- dotless i
char_types[0x0237] = char_latin -- ȷ -- dotless j
char_types[0x03DC] = char_Greek -- Ϝ -- capital digamma
char_types[0x03DD] = char_greek -- ϝ -- small digamma

local serif, sans, script, calligraphic, fraktur, mono, bb = 0, 4, 8, 12, 16, 20, 24
local bold, italic = 1, 2
local bold_default = 1024

local special_offsets = {}

local function special_offset(t)
  special_offsets[t] = true
  return t
end

local remap_bases = {
  [serif] = { -- Serif Upright
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
    0x0030,  -- 0
  },
  [serif | bold | italic] = { -- Serif Bold Italic
    0x1D468, -- 𝑨
    0x1D482, -- 𝒂
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [sans] = { -- Sans Upright
    0x1D5A0, -- 𝖠
    0x1D5BA, -- 𝖺
    0x0391, -- Α
    0x03B1, -- α
    0x1D7E2, -- 𝟢
  },
  [sans | bold] = { -- Sans Bold Upright
    0x1D5D4, -- 𝗔
    0x1D5EE, -- 𝗮
    0x1D756, -- 𝝖
    0x1D770, -- 𝝰
    0x1D7EC, -- 𝟬
  },
  [sans | italic] = { -- Sans Italic
    0x1D608, -- 𝘈
    0x1D622, -- 𝘢
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x1D7E2, -- 𝟢
  },
  [sans | bold | italic] = { -- Sans Bold Italic
    0x1D63C, -- 𝘼
    0x1D656, -- 𝙖
    0x1D790, -- 𝞐
    0x1D7AA, -- 𝞪
    0x1D7EC, -- 𝟬
  },
  [script] = { -- Script Normal -- Chancery
    special_offset{offset = 0x1D49C, vs = 0xFE00}, -- 𝒜
    special_offset{offset = 0x1D4B6, vs = 0xFE00}, -- 𝒶
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [script | bold] = { -- Script Bold -- Chancery
    special_offset{offset = 0x1D4D0, vs = 0xFE00}, -- 𝓐
    special_offset{offset = 0x1D4EA, vs = 0xFE00}, -- 𝓪
    0x1D71C, -- 𝜜
    0x1D736, -- 𝜶
    0x1D7CE, -- 𝟎
  },
  [calligraphic] = { -- Script Normal -- Roundhand
    special_offset{offset = 0x1D49C, vs = 0xFE01}, -- 𝒜
    special_offset{offset = 0x1D4B6, vs = 0xFE01}, -- 𝒶
    0x1D6E2, -- 𝛢
    0x1D6FC, -- 𝛼
    0x0030, -- 0
  },
  [calligraphic | bold] = { -- Script Bold -- Roundhand
    special_offset{offset = 0x1D4D0, vs = 0xFE01}, -- 𝓐
    special_offset{offset = 0x1D4EA, vs = 0xFE01}, -- 𝓪
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
remap_bases[unset_attribute] = { -- Default
  remap_bases[serif | italic][char_Latin], -- Latin uppercase
  remap_bases[serif | italic][char_latin], -- Latin lowercase
  remap_bases[serif][char_Greek], -- Greek uppercase
  remap_bases[serif | italic][char_greek], -- Greek lowercase
  remap_bases[serif][char_digit], -- Serif digits
}
remap_bases[bold_default] = { -- Bold Default
  remap_bases[bold][1], -- Latin uppercase
  remap_bases[bold][2], -- Latin lowercase
  remap_bases[bold][3], -- Greek uppercase
  remap_bases[bold | italic][4], -- Greek lowercase
  remap_bases[bold][5], -- Serif digits
}
do
  local base = remap_bases[0]
  remap_bases[0] = {} -- We don't want to overwrite it in the next step
  local function adjust_offset(v, i)
    local bi, vi = base[i], v[i]
    if not vi or bi == vi then
      v[i] = nil
    elseif special_offsets[vi] then
      vi.offset = vi.offset - bi
      vi.special_replacement = vs_maps[vi.vs]
    else
      v[i] = vi - bi
    end
  end
  for _, v in next, remap_bases do
    adjust_offset(v, 1)
    adjust_offset(v, 2)
    adjust_offset(v, 3)
    adjust_offset(v, 4)
    adjust_offset(v, 5)
  end
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
local sub_box_t = node.id'sub_box'
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
        local offset = remap_bases[node.get_attribute(n, attr) or unset_attribute][char_type]
        if offset then
          if special_offsets[offset] then
            local special_replacement = offset.special_replacement
            char = char + offset.offset
            char = post_replacement[char] or char
            n.char = special_replacement[(style >> 2) | (n.fam << 2)][char] or char
            -- TODO: Set properties for replacing luamml mapping
          else
            char = char + offset
            n.char = post_replacement[char] or char
          end
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

local use_i_nn = token.create'use_i:nn'
local use_ii_nn = token.create'use_ii:nn'
local bool_token = {[false] = use_ii_nn, [true] = use_i_nn}

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
      -- Currently we process all of these. We know the current style though, so we could simplify if needed.
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
        if sub == 2 then -- Handle uproot and leftroot attributes
          local leftroot = node.get_attribute(n, leftroot_attr)
          if leftroot then
            local degree = n.degree
            if degree.id == math_char_t then
              local noad = node.new(noad_t)
              noad.nucleus = degree
              degree = node.new(sub_mlist_t)
              degree.head = noad
              n.degree = degree
            end
            assert(degree.id == sub_mlist_t)
            local quad = tex.getmath('quad', style_names[style])
            leftroot = leftroot * quad // 18
            local pre_kern, post_kern = node.new'kern', node.new'kern'
            pre_kern.kern, post_kern.kern = -leftroot, leftroot
            pre_kern.kern = -leftroot
            degree.head = node.insert_after(node.insert_before(degree.head, degree.head, pre_kern), nil, post_kern)
          end
          local uproot = node.get_attribute(n, uproot_attr)
          if uproot then
            local degree = n.degree
            if degree.id == math_char_t then
              local noad = node.new(noad_t)
              noad.nucleus = degree
              degree = node.new(sub_mlist_t)
              degree.head = noad
              n.degree = degree
            end
            assert(degree.id == sub_mlist_t)
            local quad = tex.getmath('quad', style_names[style])
            uproot = uproot * quad // 18
            local new_degree = node.new(sub_box_t)
            new_degree.head = node.hpack(node.mlist_to_hlist(degree.head, 'scriptscript', false))
            degree.head = nil
            node.free(degree)
            new_degree.head.shift = -uproot
            n.degree = new_degree
          end
        end
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

tex.setmathcode(0x2A, tex.getmathcodes(0x2217)) -- '*' gets the mathcode of '∗'
tex.setmathcode(0x2D, tex.getmathcodes(0x2212)) -- '-' gets the mathcode of '−'
tex.setmathcode(0x3A, tex.getmathcodes(0x2236)) -- ':' gets the mathcode of '∶'

local slash_fence = 0x2F
tex.setdelcode(0x2F, main_fam, slash_fence, 0, 0) -- /
tex.setdelcode(0x2044, main_fam, slash_fence, 0, 0) -- ⁄
tex.setdelcode(0x2215, main_fam, slash_fence, 0, 0) -- ∕

local backslash_fence = 0x5C
tex.setdelcode(0x5C, main_fam, backslash_fence, 0, 0) -- \
tex.setdelcode(0x2216, main_fam, backslash_fence, 0, 0) -- ∖
tex.setdelcode(0x29F5, main_fam, backslash_fence, 0, 0) -- ⧵

tex.setdelcode(0x3C, tex.getdelcodes(0x27E8)) -- < => ⟨
tex.setdelcode(0x3E, tex.getdelcodes(0x27E9)) -- > => ⟩

for _, cp in ipairs{0x2191, 0x2193, 0x2195, 0x21D1, 0x21D3, 0x21D5} do -- ↑↓↕⇑⇓⇕
  tex.setdelcode(cp, main_fam, cp, 0, 0)
end

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

for _, name in ipairs{'prime', 'not', 'dots'} do
  loadfile(kpse.find_file(string.format('lua-unicode-math--%s', name), 'lua'), 'bt', environment)()
end

local func = luatexbase.new_luafunction'__l_uni_math_set_mathstyle_mappings:NNNNNN'
token.set_lua('__l_uni_math_set_mathstyle_mappings:NNNNNN', func, 'protected')
lua.get_functions_table()[func] = function()
  remap_bases[token.scan_int()] = { -- Default
    remap_bases[token.scan_int()][char_Latin], -- Latin uppercase
    remap_bases[token.scan_int()][char_latin], -- Latin lowercase
    remap_bases[token.scan_int()][char_Greek], -- Greek uppercase
    remap_bases[token.scan_int()][char_greek], -- Greek lowercase
    remap_bases[token.scan_int()][char_digit], -- Serif digits
  }
end

local func = luatexbase.new_luafunction'__l_uni_math_uproot:w'
token.set_lua('__l_uni_math_uproot:w', func, 'protected')
lua.get_functions_table()[func] = function()
  local value = token.scan_int()

  local root_nest = tex.nest[tex.nest.ptr - 1]
  local root = root_nest and root_nest.tail
  if not root or root.id ~= radical_t or root.subtype ~= 2 or root.nucleus or not root.degree then
    tex.error'Misuse'
    return
  end

  node.set_attribute(root, uproot_attr, value)
end

local func = luatexbase.new_luafunction'__l_uni_math_leftroot:w'
token.set_lua('__l_uni_math_leftroot:w', func, 'protected')
lua.get_functions_table()[func] = function()
  local value = token.scan_int()

  local root_nest = tex.nest[tex.nest.ptr - 1]
  local root = root_nest and root_nest.tail
  if not root or root.id ~= radical_t or root.subtype ~= 2 or root.nucleus or not root.degree then
    tex.error'Misuse'
    return
  end

  node.set_attribute(root, leftroot_attr, value)
end

local func = luatexbase.new_luafunction'__l_uni_math_is_integral_cp:wTF'
token.set_lua('__l_uni_math_is_integral_cp:wTF', func)
lua.get_functions_table()[func] = function()
  local value = token.scan_int()
  token.put_next(bool_token[integral_codepoints[value] or false])
end

local func = luatexbase.new_luafunction'__l_uni_math_every_math_size:'
token.set_lua('__l_uni_math_every_math_size:', func)
lua.get_functions_table()[func] = function()
  for t in pairs(mathsize_reset_maps) do
    for k in pairs(t) do
      t[k] = nil
    end
  end
end
