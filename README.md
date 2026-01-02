# lua-unicode-math

A new, experimental, faster system to load OpenType math fonts in LuaLaTeX documents.

## Usage
To start using this package, load a lua-unicode-math supported math font package like
`lum-lmodern`:

```
\documentclass{article}
\usepackage{lum-lmodern}
\begin{document}
\[
  x_{1/2}=-\frac p2\pm\sqrt{\frac{p^2}4-q}
\]
\end{document}
```

## License
The package is available under the LaTeX Project Public License, version 1.3c or later.

It is written and currently maintained by Marcel Krüger. If you encounter issues, please report them at https://github.com/zauguin/lua-unicode-math/issues.
