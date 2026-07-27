module = 'lua-unicode-math'
tdsroot = 'lualatex'

typesetexe = 'lualatex'
unpackexe = 'luatex'
unpackfiles = {'*.ins'}
installfiles = {'*.sty', 'lua-unicode-math*.lua', '*.fd'}
sourcefiles = {'*.dtx', '*.ins', '*.lua', '*.fd', '*.sty'}
textfiles = {'README.md'}
checkengines = {'luatex'}
tagfiles = {'*.dtx', '*.lua'}

function update_tag(file, content, tagname, tagdate)
  local tagyear = tagdate:sub(1, 4)
  local year = '2' * lpeg.R'09' * lpeg.R'09' * lpeg.R'09'
  local date = year * '-' * lpeg.R'09' * lpeg.R'09' * '-' * lpeg.R'09' * lpeg.R'09'
  local ws = lpeg.S' \t\n\r'^0
  if file:sub(-4) == '.dtx' then
    content = lpeg.Cs((
      lpeg.P"% Copyright (C) " * (
        year * '-' * lpeg.Cg(year * lpeg.Cc(tagyear))
        + year / function(oldyear) return oldyear == tostring(tagyear) and oldyear or string.format('%s-%s', oldyear, tagyear) end
      )
      + '\\ProvidesExplPackage' * ws * '{' * (1 - lpeg.P'}')^0 * '}' * ws * '{' * ws * lpeg.Cg(date * lpeg.Cc(tagdate)) * ws * '}' * ws * '{' * lpeg.Cg((1 - lpeg.P'}')^0 * lpeg.Cc(tagname)) * '}'
      + 1
    )^0 * -1):match(content)
  elseif file:sub(-4) == '.lua' then
    content = lpeg.Cs((
      lpeg.P"-- Copyright (C) " * (
        year * '-' * lpeg.Cg(year * lpeg.Cc(tagyear))
        + year / function(oldyear) return oldyear == tostring(tagyear) and oldyear or string.format('%s-%s', oldyear, tagyear) end
      )
      + 'local date = \'' * lpeg.Cg(date * lpeg.Cc(tagdate)) * '\'' * #lpeg.P'\n'
      + 'local version = \'v' * lpeg.Cg((1 - lpeg.P'\'')^0 * lpeg.Cc(tagname)) * '\'' * #lpeg.P'\n'
      + 1
    )^0 * -1):match(content)
  end
  return content
end
