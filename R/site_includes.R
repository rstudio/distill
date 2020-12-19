

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

site_header_extras_file <- function(site_config) {
  html_file(placeholder_html("site_in_header", site_header_extras(site_config)))
}

site_includes_html<- function(site_config, context) {
  if (context == "in_header") {
    header_html <- c()
    css_html <- c()
    with_distill_output_options(site_config, function(output_options) {
      header_html <<- includes_as_html(output_options, "in_header")
      css_html <<- css_as_html(output_options)
    })
    header_html <- tagList(header_html, site_header_extras(site_config))
    placeholder_html("site_in_header", header_html, css_html)
  } else {
    includes_html <- with_distill_output_options(site_config, function(output_options) {
      includes_as_html(output_options, context)
    })
    placeholder_html(paste0("site_", context), includes_html)
  }
}

# Checking if Cookie Consent is enabled
cc_check <- function(site_config) {
  cc_tag <- NULL
  if (!is.null(site_config$cookie_consent)) {
    cc_tag <- "text/plain"
  }else{
    cc_tag <- "text/javascript"
  }
}

site_header_extras <- function(site_config) {
  # cookieconsent.com banner
  cookie_consent <- NULL
  if (!is.null(site_config$cookie_consent)) {
    cookie_consent <- tagList(
      tags$script(type = "text/javascript",
                  src = "https://www.cookieconsent.com/releases/3.1.0/cookie-consent.js"),
      tags$script(type = "text/javascript",
                  HTML(paste(sep = "\n",
                             "\ndocument.addEventListener('DOMContentLoaded', function () {",
                             "cookieconsent.run({",
                             sprintf("'notice_banner_type':'%s',", site_config$cookie_consent$style),
                             sprintf("'consent_type': '%s',", site_config$cookie_consent$type),
                             sprintf("'palette': '%s',", site_config$cookie_consent$palette),
                             sprintf("'language': '%s',", site_config$cookie_consent$lang),
                             sprintf("'website_name': '%s',", site_config$name),
                             sprintf("'cookies_policy_url': '%s',", site_config$cookie_consent$cookies_policy),
                             "'change_preferences_selector':'#CookiePreferences'",
                             "});});")))
      )
  }

  # google analytics }
  google_analytics <- NULL
  if (!is.null(site_config$google_analytics)) {
    google_analytics <- tagList(
      tags$script(type = cc_check(site_config),
                  `cookie-consent`="tracking",
                  async = NA,
                  src = sprintf("https://www.googletagmanager.com/gtag/js?id=%s",
                                site_config$google_analytics)),
      tags$script(type = cc_check(site_config),
                  `cookie-consent`="tracking",
                  HTML(paste(sep = "\n",
                             "\nwindow.dataLayer = window.dataLayer || [];",
                             "function gtag(){dataLayer.push(arguments);}",
                             "gtag('js', new Date());",
                             sprintf("gtag('config', '%s');\n", site_config$google_analytics)
                  )))
    )
  }
  # return extras
  tagList(
    cookie_consent,
    google_analytics
  )
}

with_distill_output_options <- function(site_config, f) {
  site_config_output <- site_config[["output"]]
  if (is.list(site_config_output)) {
    distill_article_options <- site_config_output[["distill::distill_article"]]
    if (is.list(distill_article_options))
      f(distill_article_options)
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
