

site_includes <- function(site_dir, site_config) {

  # set wd to correctly resolve config paths
  oldwd <- setwd(site_dir)
  on.exit(setwd(oldwd), add = TRUE)

  in_header <- site_includes_html(site_config, "in_header")
  before_body <- site_includes_html(site_config, "before_body")
  after_body <- site_includes_html(site_config, "after_body")

  list(
    in_header = renderTags(in_header, indent = 0)$html,
    before_body = renderTags(before_body, indent = 0)$html,
    after_body = renderTags(after_body, indent = 0)$html
  )
}


site_in_header_file <- function(site_config) {
  html_file(site_includes_html(site_config, "in_header"))
}

site_before_body_file <- function(site_config) {
  html_file(site_includes_html(site_config, "before_body"))
}

site_after_body_file <- function(site_config) {
  html_file(site_includes_html(site_config, "after_body"))
}

site_includes_html<- function(site_config, context) {
  if (context == "in_header") {
    header_html <- c()
    css_html <- c()
    with_radix_output_options(site_config, function(output_options) {
      header_html <<- includes_as_html(output_options, "in_header")
      css_html <<- css_as_html(output_options)
    })
    header_html <- tagList(header_html, site_header_extras(site_config))
    placeholder_html("site_in_header", header_html, css_html)
  } else {
    includes_html <- with_radix_output_options(site_config, function(output_options) {
      includes_as_html(output_options, context)
    })
    placeholder_html(paste0("site_", context), includes_html)
  }
}

site_header_extras <- function(site_config) {

  # google analytics
  google_analytics <- NULL
  if (!is.null(site_config$google_analytics)) {
    google_analytics <- tagList(
      tags$script(async = NA,
                  src = sprintf("https://www.googletagmanager.com/gtag/js?id=%s",
                                site_config$google_analytics)),
      tags$script(HTML(paste(sep = "\n",
        "\nwindow.dataLayer = window.dataLayer || [];",
        "function gtag(){dataLayer.push(arguments);}",
        "gtag('js', new Date());",
        sprintf("gtag('config', '%s');\n", site_config$google_analytics)
      )))
    )
  }

  # return extras
  tagList(
    google_analytics
  )

}


with_radix_output_options <- function(site_config, f) {
  site_config_output <- site_config[["output"]]
  if (is.list(site_config_output)) {
    radix_article_options <- site_config_output[["radix::radix_article"]]
    if (is.list(radix_article_options))
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
