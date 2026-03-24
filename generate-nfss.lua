local date = '2026-03-24'
local version = 'v0.8'

local fmt = string.format

local copyright_notice = string.gsub(fmt([[
Copyright (C) 2024-%s
The LaTeX Project and any individual authors listed elsewhere
in this file.

this file may be distributed and/or modified under the
conditions of the LaTeX Project Public License, either version 1.3c
of this license or (at your option) any later version.
The latest version of this license is in
   https://www.latex-project.org/lppl.txt
and version 1.3c or later is part of all distributions of LaTeX
version 2008 or later.
]], os.date'%Y'), '[^\n]*', '%%%% %0') .. '\n'

local function generate_fd(writer, family_spec)
  writer(copyright_notice)
  writer(fmt("\\ProvidesFile{tu%s.fd}\n", family_spec.family))
  writer(fmt("        [%s %s NFSS font definitions for %s]\n", family_spec.date, family_spec.version, family_spec.name))
  writer(fmt("\\DeclareFontFamily{TU}{%s}{}\n", family_spec.family))
  for _, shape in ipairs(family_spec.shapes) do
    writer(fmt("\\DeclareFontShape{TU}{%s}{%s}{%s}%%\n", family_spec.family, shape.series, shape.style or 'n'))
    writer(fmt("  {<-> \\UnicodeFontFile{%s}{%s}}{}\n", shape.filename, shape.features))
  end

  if family_spec.scriptfamily then
    writer(fmt("\n\\DeclareMathScriptfontMapping{TU}{%s}{TU}{%s}{TU}{%s}", family_spec.family, family_spec.scriptfamily, family_spec.scriptscriptfamily))
  end
  writer(fmt("\n\\endinput\n"))
end

local function generate_sty(writer, family_spec)
  writer(copyright_notice)
  writer(fmt("\\ProvidesPackage{%s}\n", family_spec.package))
  writer(fmt("        [%s %s lua-unicode-math support package for %s]\n", family_spec.date, family_spec.version, family_spec.name))
  writer(fmt("\\RequirePackage{lua-unicode-math}\n", family_spec.package))
  for _, shape in ipairs(family_spec.shapes) do
    if shape.version then
      writer(fmt("\\SetSymbolFont {lummain}{%s}{TU}{%s}{%s}{%s}\n", shape.version, family_spec.family, shape.series, shape.style or 'n'))
    else
      writer(fmt("\\DeclareSymbolFont {lummain}{TU}{%s}{%s}{%s}\n", family_spec.family, shape.series, shape.style or 'n'))
    end
  end
end

local function write_fd(family_spec)
  local filename = string.format('tu%s.fd', family_spec.family)
  os.remove(filename) -- Ignore errors since the file might not exist yet
  local f = assert(io.open(filename, 'w'))
  generate_fd(function(str) assert(f:write(str)) end, family_spec)
  assert(f:close())
end

local function write_sty(family_spec)
  local filename = string.format('%s.sty', family_spec.package)
  os.remove(filename) -- Ignore errors since the file might not exist yet
  local f = assert(io.open(filename, 'w'))
  generate_sty(function(str) assert(f:write(str)) end, family_spec)
  assert(f:close())
end

local function add_feature(shapes, feature)
  local target = {}
  for i, shape in ipairs(shapes) do
    target[i] = {
      series = shape.series,
      style = shape.style,
      filename = shape.filename,
      features = shape.features .. feature,
    }
  end
  return target
end

local DEFAULT_FEATURES = 'mode=base;script=math;language=dflt;'
local function simple_shapes(filename, fakebold)
  return {{
    series = 'm',
    filename = filename,
    features = DEFAULT_FEATURES,
  }, fakebold and {
    series = 'b',
    filename = filename,
    features = fmt('%sembolden=%s;', DEFAULT_FEATURES, fakebold),
    version = 'bold',
  } or nil}
end
local function simple_and_bold(filename, bold_filename)
  return {{
    series = 'm',
    filename = filename,
    features = DEFAULT_FEATURES,
  }, {
    series = 'b',
    filename = bold_filename,
    features = DEFAULT_FEATURES,
    version = 'bold',
  }}
end

local fonts = {
  {
    family = 'lmm',
    name = "Latin Modern Math",
    package = 'lmodern',
    shapes = simple_shapes('latinmodern-math', 3),
  },
  {
    family = 'ncmm',
    name = "New Computer Modern Math",
    package = 'newcomputermodern',
    shapes = simple_and_bold('NewCMMath-Book', 'NewCMMath-Bold'),
  },
  {
    family = 'ncmsm',
    name = "New Computer Modern Sans Math",
    package = 'newcomputermodernsans',
    shapes = simple_shapes('NewCMSansMath-Regular', 3),
  },
  {
    family = 'stix2-math',
    name = "STIX2",
    package = 'stix2',
    shapes = simple_shapes('STIXTwoMath-Regular', 3),
  },
  {
    family = 'xits-math',
    name = "XITS",
    package = 'xits',
    shapes = simple_and_bold('XITSMath-Regular', 'XITSMath-Bold'),
  },
  {
    family = 'tg-pagella-math',
    name = "TeX Gyre Pagella Math",
    package = 'pagella',
    shapes = simple_shapes('texgyrepagella-math', 3),
  },
  {
    family = 'tg-dejavu-math',
    name = "TeX Gyre DejaVu Math",
    package = 'dejavu',
    shapes = simple_shapes('texgyredejavu-math', 3),
  },
  {
    family = 'tg-bonum-math',
    name = "TeX Gyre Bonum Math",
    package = 'bonum',
    shapes = simple_shapes('texgyrebonum-math', 3),
  },
  {
    family = 'tg-schola-math',
    name = "TeX Gyre Schola Math",
    package = 'schola',
    shapes = simple_shapes('texgyreschola-math', 3),
  },
  {
    family = 'tg-termes-math',
    name = "TeX Gyre Termes Math",
    package = 'termes',
    shapes = simple_shapes('texgyretermes-math', 3),
  },
  {
    family = 'fira-math',
    name = "Fira Math",
    package = 'fira',
    shapes = simple_shapes('FiraMath-Regular', 3),
  },
  {
    family = 'gfsneohellenic-math',
    name = "GFS Neohellenic Math",
    package = 'gfsneohellenic',
    shapes = simple_shapes('GFSNeohellenicMath', 3),
  },
  {
    family = 'erewhon-math',
    name = "Erewhon Math",
    package = 'erewhon',
    shapes = simple_and_bold('Erewhon-Math', 'Erewhon-Math-Bold'),
  },
  {
    family = 'xcharter-math',
    name = "XCharter Math",
    package = 'xcharter',
    shapes = simple_and_bold('XCharter-Math', 'XCharter-Math-Bold'),
  },
  {
    family = 'concmath',
    name = "Concrete Math",
    package = 'concrete',
    shapes = simple_and_bold('Concrete-Math', 'Concrete-Math-Bold'),
  },
  {
    family = 'euler-math',
    name = "Euler Math",
    package = 'euler',
    shapes = simple_shapes('Euler-Math', 3),
  },
  {
    family = 'arsenal-math',
    name = "Arsenal Math",
    package = 'arsenal',
    shapes = simple_and_bold('ArsenalMath-Sans', 'ArsenalMath-SansBold'),
  },
  {
    family = 'asana-math',
    name = "Asana Math",
    package = 'asana',
    shapes = simple_shapes('Asana-Math', 3),
  },
  {
    family = 'garamond-math',
    name = "Garamond Math",
    package = 'garamond',
    shapes = simple_shapes('Garamond-Math', 3),
  },
  {
    family = 'lete-sans-math',
    name = "Lete Sans Math",
    package = 'lete-sans',
    shapes = simple_and_bold('LeteSansMath', 'LeteSansMath-Bold'),
  },
  {
    family = 'luciole-math',
    name = "Luciole Math",
    package = 'luciole',
    shapes = simple_and_bold('Luciole-Math', 'Luciole-Math-Bold'),
  },
  {
    family = 'oldstandard-math',
    name = "Old Standard Math",
    package = 'oldstandard',
    shapes = simple_shapes('OldStandard-Math', 3),
  },
  {
    family = 'plex-math',
    name = "IBM Plex Math",
    package = 'plex',
    shapes = simple_shapes('IBMPlexMath-Regular', 3),
  },
  {
    family = 'libertinus-math',
    name = "Libertinus Math",
    package = 'libertinus',
    shapes = simple_shapes('LibertinusMath-Regular', 3),
  },
  {
    family = 'kpmath-sans',
    name = "KpMath Sans",
    package = 'kpmath-sans',
    shapes = simple_and_bold('KpMath-Sans', 'KpMath-SansBold'),
  },
}

for _, data in ipairs(fonts) do
  local scriptfamily = fmt('%s-sf', data.family)
  local scriptscriptfamily = fmt('%s-ssf', data.family)
  write_sty {
    family = data.family,
    date = date,
    version = version,
    name = data.name,
    package = 'lum-' .. data.package,
    shapes = data.shapes,
  }
  write_fd {
    family = data.family,
    date = date,
    version = version,
    name = data.name,
    scriptfamily = scriptfamily,
    scriptscriptfamily = scriptscriptfamily,
    shapes = data.shapes,
  }
  write_fd {
    family = scriptfamily,
    date = date,
    version = version,
    name = fmt("%s Script", data.name),
    shapes = add_feature(data.shapes, 'ssty=1;'),
  }
  write_fd {
    family = scriptscriptfamily,
    date = date,
    version = version,
    name = fmt("%s Subscript", data.name),
    shapes = add_feature(data.shapes, 'ssty=2;'),
  }
  print(fmt("%s & lum-%s \\\\", data.name, data.package))
end
