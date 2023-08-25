local prime_node_id = luatexbase.new_whatsit'prime'

local func = luatexbase.new_luafunction'prime_helper:w'
token.set_lua("prime_helper:w", func, 'protected')

lua.get_functions_table()[func] = function(id)
  check_math(id)
  write_whatsit_wrapped(prime_node_id, 100, token.scan_int(), 0)
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

local accent_t = node.id'accent'
local math_char_t = node.id'math_char'
local sub_mlist_t = node.id'sub_mlist'
local noad_t = node.id'noad'
local radical_t = node.id'radical'

math_whatsit_processors[prime_node_id] = function(n, parent_head, parent)
  assert(parent)
  local char = n.value
  local pre_sup, pre_sub
  local prev = parent.prev
  local prev_id = prev and prev.id
  if prev_id == noad_t or prev_id == accent_t or prev_id == radical_t then
    pre_sup, pre_sub = prev.sup, prev.sub
  else
    node.free(n)
    parent.nucleus = node.new(sub_mlist_t)
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
      if pre_sup.id == sub_mlist_t then
        mlist, new_head = pre_sup, pre_sup.head
        current_tail = node.tail(head)
      else
        new_head = node.new(noad_t, 0)
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
      if post_sup.id == sub_mlist_t then
        local post_head = post_sup.head
        current_tail.next, post_head.prev = post_head, current_tail

        if mlist then
          post_sup.head = nil
        else
          mlist = post_head
          parent.sup = nil
        end
      else
        local noad = node.node(noad_t, 0)
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
  end

  if parent ~= prev then
    node.remove(prev, parent)
    node.free(parent)
  end
  return parent_head, prev
end
