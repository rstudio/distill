html_dependency_distill <- function() {
  htmltools::htmlDependency(
    name = "distill",
    version = "2.2.21",
    src = system.file("www/distill", package = "distill"),
    script = c("template.v2.js")
  )
}

html_dependency_bowser <- function() {
  htmltools::htmlDependency(
    name = "bowser",
    version = "1.9.3",
    src = system.file("www/bowser", package = "distill"),
    script = c("bowser.min.js")
  )
}

html_dependency_webcomponents <- function() {
  htmltools::htmlDependency(
    name = "webcomponents",
    version = "2.0.0",
    src = system.file("www/webcomponents", package = "distill"),
    script = c("webcomponents.js")
  )
}

# https://github.com/bryanbraun/anchorjs
html_dependency_anchor <- function() {
  htmltools::htmlDependency(
    name = "anchor",
    version = "4.2.2",
    src = system.file("www/anchor", package = "distill"),
    script = c("anchor.min.js")
  )
}

# https://github.com/algolia/autocomplete.js
html_dependency_autocomplete <- function() {
  htmltools::htmlDependency(
    name = "autocomplete",
    version = "0.37.1",
    src = system.file("www/autocomplete", package = "distill"),
    script = c("autocomplete.min.js")
  )
}

# https://github.com/krisk/fuse
html_dependency_fuse <- function() {
  htmltools::htmlDependency(
    name = "fuse",
    version = "6.4.1",
    src = system.file("www/fuse", package = "distill"),
    script = c("fuse.min.js")
  )
}

html_dependency_headroom <- function() {
  htmltools::htmlDependency(
    name = "headroom",
    version = "0.9.4",
    src = system.file("www/headroom", package = "distill"),
    script = "headroom.min.js"
  )
}

html_dependency_iframe_resizer <- function() {
  htmltools::htmlDependency(
    name = "iframe-resizer",
    version = "3.6.1",
    src = system.file("www/iframe-resizer", package = "distill"),
    script = c("iframeResizer.min.js", "iframeResizer.contentWindow.min.js")
  )
}
