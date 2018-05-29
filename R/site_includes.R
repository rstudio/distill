

site_includes <- function(site_dir, site_config) {

  # set wd to correctly resolve config paths
  oldwd <- setwd(site_dir)
  on.exit(setwd(oldwd), add = TRUE)

  in_header <- site_in_header_as_placeholder(site_config)
  before_body <- site_includes_as_placeholder(site_config, "before_body")
  after_body <- site_includes_as_placeholder(site_config, "after_body")

  list(
    in_header = renderTags(in_header, indent = 0)$html,
    before_body = renderTags(before_body, indent = 0)$html,
    after_body = renderTags(after_body, indent = 0)$html
  )
}


render_site_in_header_as_placeholder <- function(site_config) {
  if (requires_site_placeholders(site_config))
    html_as_file(site_in_header_as_placeholder(site_config))
  else
    c()
}

site_in_header_as_placeholder <- function(site_config) {
  header_html <- c()
  css_html <- c()
  with_radix_output_options(site_config, function(output_options) {
    header_html <<- includes_as_html(output_options, "in_header")
    css_html <<- css_as_html(output_options)
  })
  placeholder_html("site_in_header", header_html, css_html)
}

render_site_before_body_as_placeholder <- function(site_config) {
  if (requires_site_placeholders(site_config))
    html_as_file(site_includes_as_placeholder(site_config, "before_body"))
  else
    c()
}

render_site_after_body_as_placeholder <- function(site_config) {
  if (requires_site_placeholders(site_config))
    html_as_file(site_includes_as_placeholder(site_config, "after_body"))
  else
    c()
}

site_includes_as_placeholder <- function(site_config, context) {
  includes_html <- with_radix_output_options(site_config, function(output_options) {
    includes_as_html(output_options, context)
  })
  placeholder_html(paste0("site_", context), includes_html)
}


requires_site_placeholders <- function(site_config) {
  # no site config requires placeholders
  if (length(site_config) == 0)
    TRUE
  # offset site config requires placeholders
  else if (!is.null(attr(site_config, "offset")))
    TRUE
  # otherwise this is a top level site file so already has the site
  # level output options merged in
  else
    FALSE
}

with_radix_output_options <- function(site_config, f) {
  site_config_output <- site_config[["output"]]
  if (!is.null(site_config_output)) {
    radix_article_options <- site_config_output[["radix::radix_article"]]
    if (!is.null(radix_article_options))
      f(radix_article_options)
    else
      c()
  } else {
    c()
  }
}

css_as_html <- function(output_options) {
  css <- output_options[["css"]]
  if (!is.null(css)) {
    css_lines <- files_to_lines(css)
    if (length(css_lines) > 0) {
      tagList(
        HTML('<style type="text/css">'),
        HTML(css_lines),
        HTML('</style>')
      )
    } else {
      c()
    }
  } else {
    c()
  }
}

includes_as_html <- function(output_options, context) {
  includes <- output_options[["includes"]]
  in_header <- includes[[context]]
  if (!is.null(in_header)) {
    HTML(files_to_lines(in_header))
  } else {
    c()
  }

}
