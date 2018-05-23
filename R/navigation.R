

navigation_in_header <- function(site_config, metadata) {
  render_navigation_html(navigation_in_header_html(site_config, metadata))
}

navigation_before_body <- function(site_config, metadata) {
  render_navigation_html(navigation_before_body_html(site_config, metadata))
}

navigation_after_body <- function(input_file, site_config, metadata) {
  render_navigation_html(navigation_after_body_html(input_file, site_config, metadata))
}

navigation_in_header_html <- function(site_config, metadata) {

  if (!is.null(site_config[["navbar"]])) {

    in_header_html <- html_from_file(
      system.file("rmarkdown/templates/radix_article/resources/navbar.html",
                  package = "radix")
    )

    in_header_html <- attachDependencies(in_header_html, list(html_dependency_headroom()))


  } else {
    in_header_html <- navigation_placeholder_html("in_header")
  }

  in_header_html

}

navigation_before_body_html <- function(site_config, metadata) {

  # helper to yield icon class
  icon_class <- function(icon) {
    if (grepl("^fa[a-z]? ", icon))
      icon
    else
      paste("fa", icon)
  }

  # if we have a navbar/header then generate it
  header <- c()
  if (!is.null(site_config[["navbar"]])) {
    build_menu <- function(menu) {
      item_to_menu <- function(item) {
        if (!is.null(item[["icon"]])) {
          icon <- tag("i", list(class = icon_class(item[["icon"]])))
          icon <- attachDependencies(icon, html_dependency_font_awesome())
        } else {
          icon <- NULL
        }
        if (!is.null(item[["text"]]) &&
            grepl("^\\s*-{3,}\\s*$", item[["text"]])) {
          tags$hr()
        } else {
          a(href = item[["href"]], icon, item[["text"]])
        }
      }
      lapply(menu, function(item) {
        if (!is.null(item[["menu"]])) {
          menu <- item[["menu"]]
          div(class = "nav-dropdown",
              htmltools::tags$button(class = "nav-dropbtn",
                                     item[["text"]],
                                     " ",
                                     span(class = "down-arrow", HTML("&#x25BE;"))
              ),
              div(class = "nav-dropdown-content", lapply(menu, item_to_menu))
          )
        } else {
          item_to_menu(item)
        }
      })
    }

    logo <- site_config[["navbar"]][["logo"]]
    if (!is.null(logo)) {
      if (is.character(logo)) {
        logo <- span(class = "logo", img(src = logo))
      } else if (is.list(logo)) {
        logo <- a(class = "logo", href = logo$href, img(src=logo$image))
      }
    }

    left_nav <- div(class = "nav-left",
                    logo,
                    a(href = "index.html", class = "title", site_config$title),
                    build_menu(site_config[["navbar"]][["left"]])
    )

    right_nav <- div(class = "nav-right",
                     build_menu(site_config[["navbar"]][["right"]]),
                     a(href = "javascript:void(0);", class = "nav-toggle", HTML("&#9776;"))
    )

    navbar <- tag("nav", list(class = "radix-site-nav radix-site-header",
                              left_nav,
                              right_nav
    ))

    header <- tag("header", list(class = "header header--fixed", role = "banner",
                                 navbar
    ))
  }

  tagList(
    HTML(navigation_begin('before_body')),
    header,
    HTML(navigation_end('before_body'))
  )
}

navigation_after_body_html <- function(input_file, site_config, metadata) {
  site_dir <- input_as_dir(input_file)
  footer <- file.path(site_dir, "footer.html")
  if (!is.null(site_config$navbar) && file.exists(footer)) {
    footer_template <- system.file("rmarkdown/templates/radix_article/resources/footer.html",
                                   package = "radix")
    footer_html <- tempfile(fileext = "html")
    pandoc_convert(
      input = normalize_path(footer),
      from = "markdown_strict",
      to = "html",
      output = footer_html,
      options = list("--template", pandoc_path_arg(footer_template),
                     "--metadata", "pagetitle:footer")
    )
    html_from_file(footer_html)
  } else {
    navigation_placeholder_html("after_body")
  }
}


navigation_placeholder <- function(context) {
  placeholder <- tempfile(fileext = "html")
  writeLines(renderTags(navigation_placeholder(context))$html, placeholder)
  placeholder
}

navigation_placeholder_html <- function(context) {
  HTML(paste(
    navigation_begin(context),
    navigation_end(context),
    sep = "\n")
  )
}

navigation_begin <- function(context) {
  paste0('<!--radix_navigation_', context ,'-->')
}

navigation_end <- function(context) {
  paste0('<!--/radix_navigation_', context, '-->')
}

html_from_file <- function(file) {
  HTML(paste(readLines(file), collapse = "\n"))
}

render_navigation_html <- function(navigation_html) {
  rendered <- renderTags(navigation_html, indent = FALSE)
  knitr::knit_meta_add(rendered$dependencies)
  file <- tempfile(fileext = "html")
  writeLines(rendered$html, file)
  file
}
