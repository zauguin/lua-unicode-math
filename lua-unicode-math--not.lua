local accent_t = node.id'accent'
local math_char_t = node.id'math_char'
local noad_t = node.id'noad'
local sub_mlist_t = node.id'sub_mlist'

local whatsit_id = luatexbase.new_whatsit'not'

local func = luatexbase.new_luafunction'not'
token.set_lua("not", func, 'protected')

lua.get_functions_table()[func] = function(id)
  check_math(id)
  write_whatsit_wrapped(whatsit_id, 100, 0, 2)
end

local not_lookup = {
  -- sed -nre '/^([0-9A-F]+);[^;]*;[^;]*;[^;]*;[^;]*;([0-9A-F]+) 0338;.*/{s//  [0x\2] = 0x\1,/;p}' < $(kpsewhich UnicodeData.txt)
  [0x2190] = 0x219A,
  [0x2192] = 0x219B,
  [0x2194] = 0x21AE,
  [0x21D0] = 0x21CD,
  [0x21D4] = 0x21CE,
  [0x21D2] = 0x21CF,
  [0x2203] = 0x2204,
  [0x2208] = 0x2209,
  [0x220B] = 0x220C,
  [0x2223] = 0x2224,
  [0x2225] = 0x2226,
  [0x223C] = 0x2241,
  [0x2243] = 0x2244,
  [0x2245] = 0x2247,
  [0x2248] = 0x2249,
  [0x003D] = 0x2260,
  [0x2261] = 0x2262,
  [0x224D] = 0x226D,
  [0x003C] = 0x226E,
  [0x003E] = 0x226F,
  [0x2264] = 0x2270,
  [0x2265] = 0x2271,
  [0x2272] = 0x2274,
  [0x2273] = 0x2275,
  [0x2276] = 0x2278,
  [0x2277] = 0x2279,
  [0x227A] = 0x2280,
  [0x227B] = 0x2281,
  [0x2282] = 0x2284,
  [0x2283] = 0x2285,
  [0x2286] = 0x2288,
  [0x2287] = 0x2289,
  [0x22A2] = 0x22AC,
  [0x22A8] = 0x22AD,
  [0x22A9] = 0x22AE,
  [0x22AB] = 0x22AF,
  [0x227C] = 0x22E0,
  [0x227D] = 0x22E1,
  [0x2291] = 0x22E2,
  [0x2292] = 0x22E3,
  [0x22B2] = 0x22EA,
  [0x22B3] = 0x22EB,
  [0x22B4] = 0x22EC,
  [0x22B5] = 0x22ED,
  [0x2ADD] = 0x2ADC,
}

math_whatsit_processors[whatsit_id] = function(_style, n, parent_head, parent)
  assert(parent)
  local after = parent.next
  if not after then
    node.free(n)
    parent.nucleus = node.new(math_char_t)
    parent.nucleus.fam, parent.nucleus.char = main_fam, 0x0338
    return parent_head, parent
  end
  if after.id == noad_t then
    local nucleus = after.nucleus
    if nucleus and nucleus.id == math_char_t and nucleus.fam == main_fam then
      local mapped = not_lookup[nucleus.char]
      if mapped then
        nucleus.char = mapped
        parent_head = node.remove(parent_head, parent)
        node.free(parent)
        return parent_head, nil, after
      end
    end

    local acc = node.new(accent_t)
    acc.overlay_accent = node.new(math_char_t)
    acc.overlay_accent.fam, acc.overlay_accent.char = main_fam, 0x0338
    acc.sub, acc.sup, after.sub, after.sup = after.sub, after.sup, nil, nil
    acc.nucleus = nucleus

    nucleus = node.new(sub_mlist_t)
    nucleus.head = acc
    after.nucleus = nucleus

    parent_head = node.remove(parent_head, parent)
    node.free(parent)
    return parent_head, nil, after
  end

  local acc = node.new(accent_t)
  acc.overlay_accent = node.new(math_char_t)
  acc.overlay_accent.fam, acc.overlay_accent.char = main_fam, 0x0338
  acc.sub, acc.sup, after.sub, after.sup = after.sub, after.sup, nil, nil
  local nucleus = node.new(sub_mlist_t)
  nucleus.head = after
  acc.nucleus = nucleus

  node.insert_after(parent_head, after, acc)
  parent_head = node.remove(parent_head, after)
  parent_head = node.remove(parent_head, parent)
  print(after, parent, acc)
  after.prev, after.next = nil, nil
  node.free(parent)

  return parent_head, nil, acc
end
