

#' R Markdown format for Radix articles
#'
#' Scientific and technical writing, native to the web.
#'
#' Radix articles feature attractive, reader-friendly typography, flexible
#' layout options for visualizations, and full support for footnotes and
#' citations.
#'
#' @inheritParams rmarkdown::html_document
#'
#' @import rmarkdown
#' @import htmltools
#'
#' @export
radix_article <- function(fig_width = 6,
                          fig_height = 4,
                          fig_retina = 2,
                          fig_caption = TRUE,
                          dev = "png",
                          smart = TRUE,
                          self_contained = TRUE,
                          mathjax = "default",
                          extra_dependencies = NULL,
                          css = NULL,
                          includes = NULL,
                          keep_md = FALSE,
                          lib_dir = NULL,
                          md_extensions = NULL,
                          pandoc_args = NULL,
                          ...) {


  # function for resolving resources
  resource <- function(name) {
    system.file("rmarkdown/templates/radix_article/resources", name,
                package = "radix")
  }

  # build pandoc args
  args <- c("--standalone")

  # prevent highlighting
  args <- c(args, "--no-highlight")

  # additional css
  for (css_file in css)
    args <- c(args, "--css", pandoc_path_arg(css_file))

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(resource("default.html")))

  # lua filter
  if (pandoc_version() >= "2.0") {
    args <- c(args, "--lua-filter",
              pandoc_path_arg(resource("distill.lua")))
  }

  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # html dependencies
  extra_dependencies <- append(extra_dependencies,
                               list(html_dependency_jquery(),
                                    html_dependency_bowser(),
                                    html_dependency_webcomponents(),
                                    html_dependency_distill()))

  # determine knitr options
  knitr_options <- knitr_options_html(fig_width = fig_width,
                                      fig_height = fig_height,
                                      fig_retina = fig_retina,
                                      keep_md = keep_md,
                                      dev = dev)
  knitr_options$opts_chunk$echo = FALSE
  knitr_options$opts_chunk$warning = FALSE
  knitr_options$opts_chunk$message = FALSE
  knitr_options$opts_chunk$comment = NA

  # hook to ensure newline at the beginning of chunks
  knitr_options$knit_hooks <- list()
  knitr_options$knit_hooks$source <- knitr_source_hook
  knitr_options$knit_hooks$chunk <- knitr_chunk_hook()

  # post-knit
  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    args <- c()

    # get site config
    site_config <- site_config(input_file, encoding)
    if (is.null(site_config))
      site_config <- list()

    # transform site_config and metadata values
    input_dir <- input_as_dir(input_file)
    site_config <- transform_site_config(input_dir, site_config)
    metadata <- transform_metadata(input_dir, site_config, metadata)

    # provide title-prefix  and qualified title if specified in site and different from title
    if (!is.null(site_config$title) && !identical(site_config$title, metadata$title)) {
      args <- c(args, "--title-prefix", site_config$title)
      metadata$qualified_title <- sprintf("%s: %s", site_config$title, metadata$title)
    } else {
      metadata$qualified_title <- metadata$title
    }

    # includes

    # header includes: radix then user
    in_header <- c(in_header_includes(input_dir, site_config, metadata),
                   includes$in_header)

    # before body includes: radix then user
    before_body <- c(before_body_includes(input_dir, site_config, metadata),
                     includes$before_body)

    # after body includes: user then radix
    after_body <- c(includes$after_body,
                    after_body_includes(input_dir, site_config, metadata))

    # args for includes
    args <- c(args, pandoc_include_args(
      in_header = in_header,
      before_body = before_body,
      after_body = after_body
    ))

    # return args
    args
  }

  # return format
  output_format(
    knitr = knitr_options,
    pandoc = pandoc_options(to = "html",
                            from = rmarkdown_format(md_extensions),
                            args = args),
    keep_md = keep_md,
    clean_supporting = self_contained,
    post_knit = post_knit,
    on_exit = validate_rstudio_version,
    base_format = html_document_base(
      smart = smart,
      self_contained = self_contained,
      lib_dir = lib_dir,
      mathjax = mathjax,
      template = "default",
      pandoc_args = pandoc_args,
      bootstrap_compatible = FALSE,
      extra_dependencies = extra_dependencies,
      ...
    )
  )
}

# detect if we are running in a Knit child process (i.e. destined
# for the internal R Markdown preview window)
validate_rstudio_version <- function() {

  # get the current rstudio version and mode (desktop vs. server)
  rstudio_version <- function() {

    # Running at the RStudio console
    if (rstudioapi::isAvailable()) {

      rstudioapi::versionInfo()

    # Running in a child process
    } else if (!is.na(Sys.getenv("RSTUDIO", unset = NA))) {

      # detect desktop vs. server using server-only environment variable
      mode <- ifelse(is.na(Sys.getenv("RSTUDIO_HTTP_REFERER", unset = NA)),
                     "desktop", "server")

      # detect version using Rmd new env var added in 1.2.638
      version <- Sys.getenv("RSTUDIO_VERSION", unset = "1.1")

      # return version info
      list(
        mode = mode,
        version = version
      )

    # Not running in RStudio
    } else {
      NULL
    }
  }

  # if we are running under rstudio then check whether this version
  # can render radix articles (since they use webcomponents polyfill)
  rstudio <- rstudio_version()
  if (!is.null(rstudio)) {

    # check for desktop mode on windows and linux (other modes are fine)
    if (!is_osx() && (rstudio$mode == "desktop")) {

      if (rstudio$version < "1.2.637")
        stop("Radix articles cannot be previewed in this version of RStudio.\n",
             "Please update to version 1.2.637 or higher at:\n",
             "https://www.rstudio.com/rstudio/download/preview/\n",
             call. = FALSE)
    }
  }
}

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
    script = c("webcomponents-bundle.js")
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

transform_site_config <- function(input_dir, site_config) {

  if (!is.null(site_config) && length(site_config) > 0) {

    # propagate navbar title to main title
    if (is.null(site_config$title) && !is.null(site_config$navbar))
      site_config$title <- site_config$navbar$title

    # propagate main title to navbar title
    if (!is.null(site_config$title) && !is.null(site_config$navbar)
        && is.null(site_config$navbar$title)) {
      site_config$navbar$title <- site_config$title
    }

    # validate that we have a title
    if (is.null(site_config$title))
      stop("_site.yml must include a title field", call. = FALSE)
  }

  site_config
}

transform_metadata <- function(input_dir, site_config, metadata) {

  # validate title
  if (is.null(metadata$title))
    stop("You must provide a title for Radix articles", call. = FALSE)

  # allow site level metadata to propagate
  site_metadata <- c("repository_url", "compare_updates_url", "creative_commons",
                     "license_url", "base_url", "preview", "slug", "citation_url",
                     "journal", "twitter")
  for (name in site_metadata)
    metadata[[name]] <- merge_lists(site_config[[name]], metadata[[name]])

  # propagate citation_url to canonical_url
  if (!is.null(metadata[["citation_url"]]) && is.null(metadata[["canonical_url"]]))
    metadata$canonical_url <- metadata$citation_url

  # parse dates
  metadata$date <- parse_date(metadata$date)
  metadata$updated <- parse_date(metadata$updated)

  if (!is.null(metadata$date)) {

    # derived date fields (used for citations)
    rfc_date <- function(date) {
      format.POSIXct(date, "%a, %d %b %Y %H:%M:%OS %z")
    }

    metadata$published_year <- format(metadata$date, "%Y")
    months <- c('Jan.', 'Feb.', 'March', 'April', 'May', 'June',
                'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.')
    metadata$published_month <- months[[as.integer(format(metadata$date, "%m"))]]
    metadata$published_day <- as.integer(format(metadata$date, "%d"))
    metadata$published_month_padded <- format(metadata$date, "%m")
    metadata$published_day_padded <- format(metadata$date, "%d")
    metadata$published_date_rfc <- rfc_date(metadata$date)
    if (!is.null(metadata$updated))
      metadata$updated_date_rfc <- rfc_date(metadata$updated)
    metadata$published_iso_date_only <- date_as_iso_8601(metadata$date, date_only = TRUE)
  }

  # normalize journal (for citations)
  if (!is.null(metadata$journal)) {
    if (is.character(metadata$journal))
      metadata$journal <- list(title = metadata$journal)
  } else {
    metadata$journal <- list()
  }

  # resolve creative commons license
  if (!is.null(metadata$creative_commons)) {

    # validate
    valid_licenses <- c("CC BY", "CC BY-SA", "CC BY-ND", "CC BY-NC",
                        "CC BY-NC-SA", "CC BY-NC-ND")
    if (!metadata$creative_commons %in% valid_licenses) {
      stop("creative_commonds license must be one of ",
           paste(valid_licenses, collapse = ", "))
    }

    # compute license url
    if (is.null(metadata$license_url)) {
      metadata$license_url <-
        paste0(
          "https://creativecommons.org/licenses/",
          tolower(sub("^CC ", "", metadata$creative_commons)), "/4.0/"
        )
    }
  }

  # base_url (strip trailing slashes)
  if (!is.null(metadata$base_url))
    metadata$base_url <- sub("/+$", "", metadata$base_url)

  # preview image
  if (!is.null(metadata$preview)) {

    # validate that the file exists
    if (!file.exists(metadata$preview)) {
      stop("Specified preview file '", metadata$preview, "' does not exist",
           call. = FALSE)
    }

    # validate that we have a base_url
    if (is.null(metadata$base_url)) {
      stop("You must specify a base_url to resolve relative image paths against ",
           "when specifying a preview image ",
          "(Open Graph and Twitter preview images must use absolute URLs", call. = FALSE)
    }

    # if it's a png then determine it's dimensions
    if (is_file_type(metadata$preview, "png")) {
      png <- png::readPNG(metadata$preview)
      metadata$preview_width <- ncol(png)
      metadata$preview_height <- nrow(png)
    }

    # resolve preview url
    metadata$preview <- file.path(metadata$base_url, metadata$preview)
  }

  # authors
  if (!is.null(metadata$author)) {

    # compute first and last name
    metadata$author <- lapply(metadata$author, function(author) {
      names <- strsplit(author$name, '\\s+')[[1]]
      author$first_name <- paste(utils::head(names, -1))
      author$last_name <- utils::tail(names, 1)
      author
    })

    # compute concatenated authors
    metadata$concatenated_authors <-
      if (length(metadata$author) > 2)
        paste0(metadata$author[[1]]$last_name, ', et al.')
      else if (length(metadata$author) == 2)
        paste(metadata$author[[1]]$last_name, '&', metadata$author[[2]]$last_name)
      else if (length(metadata$author) == 1)
        metadata$author[[1]]$last_name

    # compute bibtex authors
    metadata$bibtex_authors <-
      paste(collapse = " and ", sapply(metadata$author, function(author) {
        paste0(author$last_name, ', ', author$first_name)
      }))

    # slug
    if (is.null(metadata$slug) && !is.null(metadata$date)) {
      metadata$slug <- paste0(tolower(metadata$author[[1]]$last_name),
                              metadata$published_year,
                              tolower(strsplit(metadata$title, ' ')[[1]][[1]]))
    }
  }

  # failsafe for slug
  if (is.null(metadata$slug))
    metadata$slug <- "Untitled"

  metadata
}

in_header_includes <- function(input_dir, site_config, metadata) {

  in_header <- c()

  # description
  description_meta <- list()
  if (!is.null(metadata$description)) {
    description_meta[[1]] <- tags$meta(
      property="description", itemprop="description", content=metadata$description
    )
  }

  # links
  links <- list()
  if (!is.null(metadata$canonical_url)) {
    links[[1]] <- tags$link(
      rel = "canonical",
      href = metadata$canonical_url
    )
  }
  if (!is.null(metadata$license_url)) {
    links[[length(links) + 1]] <- tags$link(
      rel = "license",
      href = metadata$license_url
    )
  }
  if (!is.null(site_config$favicon)) {
    links[[length(links) + 1]] <- tags$link(
      rel = "icon",
      type = mime::guess_type(site_config$favicon),
      href = site_config$favicon
    )
  }


  # authors meta tags
  author_meta <- lapply(metadata$author, function(author) {
    if (!is.list(author) || is.null(author$name) || is.null(author$url))
      stop("author metadata must include name and url fields", call. = FALSE)
    tags$meta(name="article:author", content=author$name)
  })

  article_meta <- list()
  if (!is.null(metadata$date)) {
    date <- format.Date(metadata$date, "%Y-%m-%d")
    article_meta <- tagList(
      HTML("<!--  https://schema.org/Article -->"),
      tags$meta(property="article:published", itemprop="datePublished", content=date),
      tags$meta(property="article:created", itemprop="dateCreated", content=date)
    )
  }

  # updated date
  updated_meta <- list()
  if (!is.null(metadata$updated)) {
    updated <-  date_as_iso_8601(metadata$updated)
    updated_meta[[1]] <- tags$meta(
      property="article:modified", itemprop="dateModified", content=updated
    )
  }

  # open graph (https://developers.facebook.com/docs/sharing/webmasters#markup)
  open_graph_meta <- open_graph_metadata(site_config, metadata)

  # twitter card (https://dev.twitter.com/cards/types/summary)
  twitter_card_meta <- twitter_card_metadata(site_config, metadata)

  # google scholar (https://scholar.google.com/intl/en/scholar/inclusion.html)
  google_scholar_meta <- google_scholar_metadata(site_config, metadata)

  # render head tags
  meta_tags <- do.call(tagList, list(
    description_meta,
    HTML(''),
    links,
    HTML(''),
    article_meta,
    updated_meta,
    author_meta,
    HTML(''),
    open_graph_meta,
    HTML(''),
    twitter_card_meta,
    HTML(''),
    google_scholar_meta
  ))
  meta_html <- as.character(meta_tags)
  meta_file <- tempfile(fileext = "html")
  writeLines(meta_html, meta_file)
  in_header <- c(in_header, meta_file)

  # if we have a site navbar
  if (!is.null(site_config[["navbar"]])) {

    # dependency on headroom.js for auto-hide navbar
    knitr::knit_meta_add(list(html_dependency_headroom()))

    # add our site css
    in_header <- c(in_header,
        system.file("rmarkdown/templates/radix_article/resources/navbar.html",
                    package = "radix")
    )
  }

  in_header

}

open_graph_metadata <- function(site_config, metadata) {

  # core descriptors
  open_graph_meta <- list(
    HTML("<!--  https://developers.facebook.com/docs/sharing/webmasters#markup -->"),
    tags$meta(property = "og:title", content = metadata$qualified_title),
    tags$meta(property = "og:type", content = "article")
  )

  # add a property
  add_open_graph_meta <- function(property, content) {
    if (!is.null(content)) {
      open_graph_meta[[length(open_graph_meta)+1]] <<-
        tags$meta(property = property, content = content)
    }
  }

  # description
  add_open_graph_meta("og:description", metadata$description)

  # cannonical url
  add_open_graph_meta("og:url", metadata$canonical_url)

  # preivew/thumbnail url
  add_open_graph_meta("og:image", metadata$preview)
  add_open_graph_meta("og:image:width", metadata$preview_width)
  add_open_graph_meta("og:image:height", metadata$preview_height)

  # locale
  locale <- if (!is.null(metadata$lang))
    metadata$lang
  else if (!is.null(site_config$lang))
    site_config$lang
  else
    "en_US"
  add_open_graph_meta("og:locale", locale)

  # site name
  add_open_graph_meta("og:site_name", site_config$title)

  open_graph_meta
}

twitter_card_metadata <- function(site_config, metadata) {

  twitter_card_meta <- list(
    HTML("<!--  https://dev.twitter.com/cards/types/summary -->")
  )

  # add a property
  add_twitter_card_meta <- function(property, content) {
    if (!is.null(content)) {
      twitter_card_meta[[length(twitter_card_meta)+1]] <<-
        tags$meta(property = property, content = content)
    }
  }

  # card type
  card_type <- if(!is.null(metadata$preview)) "summary_large_image" else "summary"
  add_twitter_card_meta("twitter:card", card_type)

  # title and description
  add_twitter_card_meta("twitter:title", metadata$qualified_title)
  add_twitter_card_meta("twitter:description", metadata$description)

  # cannonical url
  add_twitter_card_meta("twitter:url", metadata$canonical_url)

  # preview image
  add_twitter_card_meta("twitter:image", metadata$preview)
  add_twitter_card_meta("twitter:image:width", metadata$preview_width)
  add_twitter_card_meta("twitter:image:height", metadata$preview_height)

  # twitter attribution
  if (!is.null(metadata$twitter)) {
    add_twitter_card_meta("twitter:site", metadata$twitter$site)
    add_twitter_card_meta("twitter:creator", metadata$twitter$creator)
  }

  twitter_card_meta
}

# see https://github.com/scieloorg/opac/files/1136749/Metatags.for.Bibliographic.Metadata.Google.Scholar.-.COMPLETE.pdf

google_scholar_metadata <- function(site_config, metadata) {

  # empty if not citable
  if (!is_citeable(metadata))
    return(list())

  google_scholar_meta <- list(
    HTML("<!--  https://scholar.google.com/intl/en/scholar/inclusion.html#indexing -->"),
    tags$meta(name = "citation_title", content = metadata$qualified_title)
  )

  # helper to add properties
  add_meta <- function(property, content) {
    if (!is.null(content)) {
      google_scholar_meta[[length(google_scholar_meta)+1]] <<-
        tags$meta(name = property, content = content)
    }
  }

  add_meta("citation_fulltext_html_url", metadata$citation_url)
  add_meta("citation_volume", metadata$volume)
  add_meta("citation_issue", metadata$issue)
  add_meta("citation_doi", metadata$doi)
  journal <- metadata$journal
  journal_title <- if (!is.null(journal$full_title) )
    journal$full_title
  else
    journal$title
  add_meta("citation_journal_title", journal$title)
  add_meta("citation_journal_abbrev", journal$abbrev_title)
  add_meta("citation_issn", journal$issn)
  add_meta("citation_publisher", journal$publisher)
  if (!is.null(metadata$creative_commons))
    add_meta("citation_fulltext_world_readable", "")
  citation_date <- sprintf("%s/%s/%s",
    metadata$published_year,
    metadata$published_month_padded,
    metadata$published_day_padded
  )
  add_meta("citation_online_date", citation_date);
  add_meta("citation_publication_date", citation_date);
  for (author in metadata$author) {
    add_meta("citation_author", author$name)
    add_meta("citation_author_institution", author$affiliation)
  }

  # references
  if (!is.null(metadata$bibliography)) {
    references <- pandoc_citeproc_convert(metadata$bibliography)
    for (ref in references)
      add_meta("citation_reference", citation_reference(ref))
  }

  google_scholar_meta
}

citation_reference <- function(ref) {

  # collect fields
  names <- c()
  values <- c()
  add_field <- function(name, value)  {
    if (!is.null(value)) {
      names <<- c(names, name)
      values <<- c(values, value)
    }
  }
  add_ref_field <- function(name) {
    add_field(name, ref[[name]])
  }
  add_ref_field("title")
  if (!is.null(ref$issued))
    add_field("publication_date", ref[["issued"]][["date-parts"]][[1]][[1]])
  add_ref_field("publisher")

  # TODO: arxiv test  here
  add_field("journal_title", ref[["journal"]])
  add_ref_field("volume")
  add_ref_field("number")

  add_field("doi", ref[["DOI"]])
  add_field("issn", ref[["ISSN"]])
  if (!is.null(ref[["author"]])) {
    for (author in ref$author)
      add_field("author", paste(author[["given"]], author[["family"]]))
  }

  # prepend 'citation'
  names <- paste0("citation_", names)

  # combine name & value
  fields <- paste(names, values, sep = "=")
  paste(fields, collapse = ";")
}


before_body_includes <- function(input_dir, site_config, metadata) {

  # front matter script
  front_matter_script <- HTML(paste(c(
    '',
    '<script id="distill-front-matter" type="text/json">',
    front_matter_from_metadata(metadata),
    '</script>',
    '') ,collapse = "\n")
  )


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
          knitr::knit_meta_add(list(html_dependency_font_awesome()))
          icon <- tag("i", list(class = icon_class(item[["icon"]])))
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

  before_body_html <- renderTags(tagList(
    front_matter_script,
    header
  ), indent = FALSE)$html

  # write and return file
  before_body <- tempfile(fileext = "html")
  writeLines(before_body_html, before_body)
  before_body
}

after_body_includes <- function(input_dir, site_config, metadata) {

  # write appendixes
  updates_and_corrections <- appendix_updates_and_corrections(site_config, metadata)
  creative_commons <- appendix_creative_commons(site_config, metadata)
  citation <- appendix_citation(site_config, metadata)
  appendix <- tags$div(class = "appendix-bottom",
    updates_and_corrections,
    creative_commons,
    citation
  )

  # write bibliography
  bibliography <- c()
  if (!is.null(metadata$bibliography)) {
    bibliography <- HTML(paste(c(
      '<script id="distill-bibliography" type="text/bibtex">',
      readLines(metadata$bibliography, warn = FALSE),
      '</script>'
    ), collapse = "\n"))
  }

  after_body_html <- renderTags(tagList(
    appendix,
    bibliography
  ), indent = FALSE)$html

  # write file
  after_body <- tempfile(fileext = "html")
  writeLines(after_body_html, after_body)

  # footer if we have a site navbar there is a footer.html
  footer <- file.path(input_dir, "footer.html")
  if (!is.null(site_config$navbar) && file.exists(footer)) {
    footer_template <- system.file("rmarkdown/templates/radix_article/resources/footer.html",
                                   package = "radix")
    footer_html <- tempfile(fileext = "html")
    pandoc_convert(
      input = footer,
      from = "markdown_strict",
      to = "html",
      output = footer_html,
      options = list("--template", pandoc_path_arg(footer_template),
                     "--metadata", "pagetitle:footer")
    )
    after_body <- c(after_body, footer_html)
  }

  after_body
}

front_matter_from_metadata <- function(metadata) {
  front_matter <- list()
  front_matter$title <- metadata$title
  front_matter$description <- metadata$description
  front_matter$doi <- metadata$doi
  front_matter$authors <- lapply(metadata$author, function(author) {
    list(
      author = author$name,
      authorURL = author$url,
      affiliation = not_null(author$affiliation, "&nbsp;"),
      affiliationURL = not_null(author$affiliation_url, "#")
    )
  })
  if (!is.null(metadata$date))
    front_matter$publishedDate <- date_as_iso_8601(metadata$date)
  if (!is.null(metadata$concatenated_authors) && !is.null(metadata$published_year)) {
    front_matter$citationText <- sprintf("%s, %s",
                                          metadata$concatenated_authors,
                                          metadata$published_year)
  }
  jsonlite::toJSON(front_matter, auto_unbox = TRUE)
}

appendix_updates_and_corrections <- function(site_config, metadata) {

  if (!is.null(metadata$repository_url)) {

    updates_and_corrections <- list()
    if (!is.null(metadata$compare_updates_url)) {
      updates_and_corrections[[length(updates_and_corrections) + 1]] <-
        tags$span(
          tags$a(href = metadata$compare_updates_url, "View all changes"),
          " to this article since it was first published. "
        )
    }

    issues_url <- metadata$repository_url
    if (grepl("github.com", issues_url, fixed = TRUE)) {
      issues_url <- sub("/$", "", issues_url)
      issues_url <- paste0(issues_url, "/issues/new")
    }
    updates_and_corrections[[length(updates_and_corrections) + 1]] <-
      HTML(sprintf(paste0(
        'If you see mistakes or want to suggest changes, please ',
        '<a href="%s">create an issue</a> on the source repository.'
      ), htmlEscape(issues_url, attribute = TRUE)))

    tagList(
      tags$h3(id = "updates-and-corrections", "Updates and Corrections"),
      tags$p(
        updates_and_corrections
      )
    )


  } else {
    NULL
  }
}

appendix_creative_commons <- function(site_config, metadata) {

  if (!is.null(metadata$creative_commons)) {

    source_note <- if (!is.null(metadata$repository_url)) {
      sprintf(paste0('Source code is available at <a href="%s">%s</a>, ',
                     'unless otherwise noted. '),
              htmlEscape(metadata$repository_url, attribute = TRUE),
              htmlEscape(metadata$repository_url)
      )
    } else {
      ""
    }

    reuse_note <- sprintf(
      paste0(
        'Text and figures are licensed under Creative Commons Attribution ',
        '<a rel="license" href="%s">%s 4.0</a>. %sThe figures that have been reused from ',
        'other sources don\'t fall under this license and can be ',
        'recognized by a note in their caption: "Figure from ...".'
      ),
      htmlEscape(metadata$license_url, TRUE),
      htmlEscape(metadata$creative_commons),
      source_note
    )

    list(
      tags$h3(id = "reuse", "Reuse"),
      tags$p(HTML(reuse_note))
    )
  } else {
    NULL
  }
}

appendix_citation <- function(site_config, metadata) {

  if (is_citeable(metadata)) {

    short_citation <- function() {
      if (!is.null(metadata$journal$title)) {
        sprintf('%s, "%s", %s, %s',
                metadata$concatenated_authors,
                metadata$qualified_title,
                metadata$journal$title,
                metadata$published_year)
      } else {
        sprintf('%s (%s, %s %d). %s. Retrieved from %s',
                metadata$concatenated_authors,
                metadata$published_year,
                metadata$published_month,
                metadata$published_day,
                metadata$qualified_title,
                metadata$citation_url)
      }
    }

    long_citation <- function() {
      if (!is.null(metadata$journal$title)) {

        suffix <- c()
        sep <- ifelse(!is.null(metadata$citation_url) && !is.null(metadata$doi), ",", "")
        if (!is.null(metadata$citation_url))
          suffix <- c(suffix, sprintf(',\n  note = {%s}', metadata$citation_url))
        if (!is.null(metadata$doi))
          suffix <- c(suffix, sprintf(',\n  doi = {%s}', metadata$doi))
        suffix <- paste0(c(suffix, '\n}'), collapse = '')
        sprintf(paste('@article(%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  journal = {%s},',
                      '  year = {%s}%s',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                metadata$qualified_title,
                metadata$journal$title,
                metadata$published_year,
                suffix
        )
      } else {
        sprintf(paste('@misc(%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  url = {%s},',
                      '  year = {%s}',
                      '}',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                metadata$qualified_title,
                metadata$citation_url,
                metadata$published_year
        )
      }
  }

    list(
      tags$h3(id = "citation", "Citation"),
      tags$p("For attribution, please cite this work as"),
      tags$pre(class = "citation-appendix short", short_citation()),
      tags$p("BibTeX citation"),
      tags$pre(class = "citation-appendix long", long_citation())
    )

  } else {
    NULL
  }

}

is_citeable <- function(metadata) {
  !is.null(metadata$date) &&
    !is.null(metadata$author) &&
    (!is.null(metadata$citation_url) || !is.null(metadata$journal$title))
}

knitr_source_hook <- function(x, options) {

  # determine language/class
  language <- tolower(options$engine)
  if (language == 'node') language <- 'javascript'
  if (!is.null(options$class.source))
    language <- block_class(c(language, options$class.source))

  # pad newline if necessary
  if (length(x) > 0 && !nzchar(x[[1]]))
    x <- c("", x)

  # form output
  paste(
    '',
    sprintf('```%s', language),
    '',
    paste0(x, collapse = '\n'),
    '```',
    '',
    sep = '\n'
  )
}

knitr_chunk_hook <- function() {

  # capture the default chunk hook
  previous_hooks <- knitr::knit_hooks$get()
  on.exit(knitr::knit_hooks$restore(previous_hooks), add = TRUE)
  knitr::render_markdown()
  default_chunk_hook <- knitr::knit_hooks$get("chunk")

  # hook
  function(x, options) {

    # apply default layout
    if (is.null(options$layout))
      options$layout <- "l-body"

    # apply default hook and determine padding
    output <- default_chunk_hook(x, options)
    pad_chars <- nchar(output) - nchar(sub("^ +", "", output))
    padding <- paste(rep(' ', pad_chars), collapse = '')

    # enclose default output in div (with appropriate padding)
    paste0(
      padding, '<div class="layout-chunk ', options$layout, '">\n',
      output, '\n',
      padding, '\n',
      padding, '</div>\n'
    )
  }
}








