

navigation_in_header <- function(site_config) {
  render_navigation_html(navigation_in_header_html(site_config))
}

navigation_before_body <- function(site_config) {
  render_navigation_html(navigation_before_body_html(site_config))
}

navigation_after_body <- function(site_dir, site_config) {
  render_navigation_html(navigation_after_body_html(site_dir, site_config))
}

navigation_in_header_file <- function(site_config) {
  render_navigation_html_file(navigation_in_header_html(site_config))
}

navigation_before_body_file <- function(site_config) {
  render_navigation_html_file(navigation_before_body_html(site_config))
}

navigation_after_body_file <- function(site_dir, site_config) {
  render_navigation_html_file(navigation_after_body_html(site_dir, site_config))
}

navigation_in_header_html <- function(site_config) {

  if (!is.null(site_config[["navbar"]])) {

    in_header_html <- html_from_file(
      system.file("rmarkdown/templates/radix_article/resources/navbar.html",
                  package = "radix")
    )

  } else {
    in_header_html <- navigation_placeholder_html("in_header")
  }

  in_header_html

}

navigation_before_body_html <- function(site_config) {

  # if we have a navbar/header then generate it
  header <- c()
  if (!is.null(site_config[["navbar"]])) {
    build_menu <- function(menu) {
      item_to_menu <- function(item) {
        if (!is.null(item[["image"]])) {
          a(href = item[["href"]], class="nav-image", img(src = item[["image"]]))
        } else if (!is.null(item[["text"]]) &&
            grepl("^\\s*-{3,}\\s*$", item[["text"]])) {
          tags$hr()
        } else {
          a(href = item[["href"]], item[["text"]])
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
                    span(class = "title", site_config$title),
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

  placeholder_html("navigation_before_body", header)
}

navigation_after_body_html <- function(site_dir, site_config) {
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

    footer_html <- fixup_navigation_paths(footer_html, site_dir, site_config)

    html_from_file(footer_html)

  } else {
    navigation_placeholder_html("after_body")
  }
}



navigation_html_generator <- function() {

  cache <- new.env(parent = emptyenv())

  function(site_dir, site_config, offset) {

    # populate cache if we need to
    if (!exists(offset, envir = cache)) {

      # offset the config
      site_config <- offset_site_config(site_dir, site_config, offset)

      # generate html and assign into cache
      assign(offset, envir = cache, list(
        in_header = navigation_in_header(site_config),
        before_body = navigation_before_body(site_config),
        after_body = navigation_after_body(site_dir, site_config)
      ))
    }

    # return html
    get(offset, envir = cache)

  }
}

fixup_navigation_paths <- function(file, site_dir, site_config) {

  # check for offset
  offset <- attr(site_config, "offset")

  # function to fixup an element type
  fixup_element_paths <- function(html, tag, attrib) {
    tags <- xml2::xml_find_all(html, paste0(".//", tag))
    for (tag in tags) {
      path <- xml2::xml_attr(tag, attrib)
      if (!is.na(path)) {
        if (file.exists(file.path(site_dir, site_config$output_dir, path)))
          xml2::xml_attr(tag, attrib) <- file.path(offset, path)
      }
    }
  }

  # process if necessary
  if (!is.null(offset)) {
    html <- xml2::read_xml(file)
    fixup_element_paths(html, "a", "href")
    fixup_element_paths(html, "img", "src")
    tmp <- tempfile(fileext = ".html")
    xml2::write_xml(html, tmp, options = c("format", "no_declaration"))
    file <- tmp
  }

  file
}

navigation_placeholder_html <- function(context) {
  HTML(paste(
    navigation_begin(context),
    navigation_end(context),
    sep = "\n")
  )
}

navigation_begin <- function(context) {
  placeholder_begin(paste0("navigation_", context))
}

navigation_end <- function(context) {
  placeholder_end(paste0("navigation_", context))
}

render_navigation_html <- function(navigation_html) {
  rendered <- renderTags(navigation_html, indent = FALSE)
  knitr::knit_meta_add(rendered$dependencies)
  rendered$html
}

render_navigation_html_file <- function(navigation_html) {
  html <- render_navigation_html(navigation_html)
  file <- tempfile(fileext = "html")
  writeLines(html, file)
  file
}



