

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
  begin <- placeholder_begin(context)
  begin_pos <- regexpr(begin, html, fixed = TRUE)
  end <- placeholder_end(context)
  end_pos <- regexpr(end, html, fixed = TRUE)
  if (begin_pos >= 0 && end_pos >= 0) {
    paste0(
      substring(html, first = 1, last = begin_pos - 1),
      content,
      substring(html,
                first = end_pos + attr(end_pos, "match.length"),
                last = nchar(html))
    )
  } else {
    html
  }
}
