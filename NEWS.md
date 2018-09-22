
## radix 0.6 (Unreleased)

Install the development version with `devtools::install_github("rstudio/radix")`

* Support for bookdown-style figure cross-references (e.g. `\@ref{fig:plot1}`)

* Allow use of markdown within footnotes

* Support for text headers within website navigation menus

* Fix issue with RStudio version check (check was failing with 4-digit patch version)

* Recover gracefully from invalid posts.json file (e.g. due to git merge)

* Syntax highlighting for unknown languages (now they are mapped to "clike", previously they were removed entirely)


## radix 0.5 (CRAN)

* Initial CRAN release
