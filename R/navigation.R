

navigation_in_header <- function(site_config, offset) {
  render_navigation_html(navigation_in_header_html(site_config, offset))
}

navigation_before_body <- function(site_config, offset) {
  render_navigation_html(navigation_before_body_html(site_config, offset))
}

navigation_after_body <- function(site_dir, site_config, offset) {
  render_navigation_html(navigation_after_body_html(site_dir, site_config, offset))
}

navigation_in_header_file <- function(site_config, offset = NULL) {
  render_navigation_html_file(navigation_in_header_html(site_config, offset))
}

navigation_before_body_file <- function(site_config, offset = NULL) {
  render_navigation_html_file(navigation_before_body_html(site_config, offset))
}

navigation_after_body_file <- function(site_dir, site_config, offset = NULL) {
  render_navigation_html_file(navigation_after_body_html(site_dir, site_config, offset))
}

navigation_html_generator <- function() {

  cache <- new.env(parent = emptyenv())

  function(site_dir, site_config, offset) {

    # populate cache if we need to
    if (!exists(offset, envir = cache)) {

      # generate html and assign into cache
      assign(offset, envir = cache, list(
        in_header = navigation_in_header(site_config, offset),
        before_body = navigation_before_body(site_config, offset),
        after_body = navigation_after_body(site_dir, site_config, offset)
      ))
    }

    # return html
    get(offset, envir = cache)

  }
}

navigation_in_header_html <- function(site_config, offset) {

  if (!is.null(site_config[["navbar"]])) {

    in_header_html <- html_from_file(
      system.file("rmarkdown/templates/radix_article/resources/navbar.html",
                  package = "radix")
    )

    in_header_html <- tagList(
      HTML("<!--radix_placeholder_navigation_in_header-->"),
      in_header_html,
      lapply(site_dependencies(site_config), function(lib) {
        if (!is.null(offset))
          lib$path <- file.path(offset, lib$path)
        list(
          lapply(lib$dep$stylesheet, function(css) { tags$link(href = file.path(lib$path, css), rel = "stylesheet") }),
          lapply(lib$dep$script, function(script) { tags$script(src = file.path(lib$path, script)) } )
        )
      }),
      HTML("<!--/radix_placeholder_navigation_in_header-->")
    )

  } else {
    in_header_html <- navigation_placeholder_html("in_header")
  }

  in_header_html

}

navigation_before_body_html <- function(site_config, offset) {

  # helper to apply offset (if any)
  offset_href <- function(href) {
    if (is.null(href))
      NULL
    else if (!is.null(offset) && !is_url(href))
      file.path(offset, href)
    else
      href
  }

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
        item$href <- offset_href(item$href)
        item$image <- offset_href(item$image)
        if (!is.null(item[["icon"]])) {
          icon <- tag("i", list(class = icon_class(item[["icon"]])))
          a(href = item[["href"]], icon)
        } else if (!is.null(item[["image"]])) {
          a(href = item[["href"]], class="nav-image", img(src = item[["image"]]))
        } else if (!is.null(item[["text"]]) &&
                    grepl("^\\s*-{3,}\\s*$", item[["text"]])) {
          tags$hr()
        } else if (!is.null(item[["href"]])) {
          a(href = item[["href"]], item[["text"]])
        } else {
          span(class = "nav-dropdown-header", item[["text"]])
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
        logo <- span(class = "logo", img(src = offset_href(logo)))
      } else if (is.list(logo)) {
        logo <- a(class = "logo",
                  href = offset_href(logo$href),
                  img(src= offset_href(logo$image)))
      }
    }

    left_nav <- div(class = "nav-left",
                    logo,
                    a(href = offset_href("index.html"), class = "title", site_config$navbar$title),
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

navigation_after_body_html <- function(site_dir, site_config, offset) {
  footer <- file.path(site_dir, "_footer.html")
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

    footer_html <- fixup_navigation_paths(footer_html, site_dir, site_config, offset)

    html_from_file(footer_html)

  } else {
    navigation_placeholder_html("after_body")
  }
}


fixup_navigation_paths <- function(file, site_dir, site_config, offset) {

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


find_site_dir <- function(input_file) {
  tryCatch(
    rprojroot::find_root(
      criterion =  rprojroot::has_file("_site.yml"),
      path = dirname(input_file)
    ),
    error = function(e) NULL
  )
}

ensure_site_dependencies <- function(site_config, site_dir) {
  for (lib in site_dependencies(site_config)) {
    lib_path <- file.path(site_dir, lib$path)
    if (!dir_exists(lib_path))
      copyDependencyToDir(lib$dep, file.path(site_dir, dirname(lib$path)))
  }
}


site_dependencies <- function(site_config) {

  site_dependency <- function(dep) {
    ver <- paste(dep$name, dep$version, sep = "-")
    path <- file.path("site_libs", ver)
    list(
      dep = dep,
      ver = ver,
      path = path
    )
  }

  if (length(site_config) > 0) {
    list(
      site_dependency(html_dependency_font_awesome()),
      site_dependency(html_dependency_headroom())
    )
  } else {
    list()
  }
}





