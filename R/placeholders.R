

placeholder_html <- function(context, ...) {
  tagList(
    HTML(placeholder_begin(context)),
    list(...),
    HTML(placeholder_end(context))
  )
}

placeholder_begin <- function(context) {
  paste0('<!--radix_placeholder_', context ,'-->')
}

placeholder_end <- function(context) {
  paste0('<!--/radix_placeholder_', context, '-->')
}

fill_placeholder <- function(html, context, content) {
  pattern <- paste0(placeholder_begin(context), ".*", placeholder_end(context))
  sub(pattern, content, html, useBytes = TRUE)
}
