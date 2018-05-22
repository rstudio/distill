html_dependency_distill <- function() {
  htmltools::htmlDependency(
    name = "distill",
    version = "2.2.21",
    src = system.file("www/distill", package = "radix"),
    script = c("template.v2.js", "distill.js"),
    stylesheet = c("distill.css")
  )
}

html_dependency_bowser <- function() {
  htmltools::htmlDependency(
    name = "bowser",
    version = "1.9.3",
    src = system.file("www/bowser", package = "radix"),
    script = c("bowser.min.js")
  )
}

html_dependency_webcomponents <- function() {
  htmltools::htmlDependency(
    name = "webcomponents",
    version = "2.0.0",
    src = system.file("www/webcomponents", package = "radix"),
    script = c("webcomponents.js")
  )
}

html_dependency_headroom <- function() {
  htmltools::htmlDependency(
    name = "headroom",
    version = "0.9.4",
    src = system.file("www/headroom", package = "radix"),
    script = "headroom.min.js"
  )
}

html_dependency_iframe_resizer <- function(context = c("host", "content")) {
  context <- match.arg(context)
  js_suffix <- if (context == "content") ".contentWindow"
  htmltools::htmlDependency(
    name = paste0("iframe_resizer_", context),
    version = "3.6.1",
    src = system.file("www/iframe-resizer", package = "radix"),
    script = paste0("iframeResizer", js_suffix, ".min.js"),
    all_files = FALSE
  )
}
