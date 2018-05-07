

#' R Markdown format for Distill articles
#'
#' Distill is a framework for creating technical articles for the web.
#'
#' Distill articles feature attractive, reader-friendly typography, flexible
#' layout options for visualizations, and full support for footnotes and
#' citations.
#'
#' @inheritParams rmarkdown::html_document
#'
#' @import rmarkdown
#' @import htmltools
#'
#' @export
distill_article <- function(fig_width = 6,
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
    system.file("rmarkdown/templates/distill_article/resources", name,
                package = "distill")
  }

  # build pandoc args
  args <- c("--standalone")

  # prevent highlighting
  args <- c(args, "--no-highlight")

  # additional css
  for (css_file in css)
    args <- c(args, "--css", pandoc_path_arg(css_file))

  # content includes
  args <- c(args, includes_to_pandoc_args(includes))

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(resource("default.html")))

  # lua filter
  if (pandoc_version() >= "2.0") {
    args <- c(args, "--lua-filter",
              pandoc_path_arg(resource("distill-2.0/distill.lua")))
  }

  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # html dependency for distill
  extra_dependencies <- append(extra_dependencies,
                               list(html_dependency_jquery(),
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
  knitr_options$knit_hooks$chunk <- knitr_chunk_hook

  # post-knit
  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    args <- c()

    # get site config
    site_config <- site_config(input_file, encoding)

    # transform metadata values (e.g. date)
    metadata$date <- parse_date(metadata$date)
    metadata$updated <- parse_date(metadata$updated)

    # metadata
    args <- c(args, pandoc_include_args(
      in_header = in_header_includes(site_config, metadata),
      before_body = before_body_includes(site_config, metadata),
      after_body = after_body_includes(site_config, metadata)
    ))

    args
  }

  # preprocessor
  pre_processor <- function (metadata, input_file, runtime, knit_meta,
                             files_dir, output_dir) {
    c()
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
    pre_processor = pre_processor,
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

html_dependency_distill <- function() {
  htmltools::htmlDependency(
    name = "distill",
    version = "2.2.21",
    src = system.file("rmarkdown/templates/distill_article/resources/distill-2.0",
                      package = "distill"),
    script = c("distill.js", "template.v2.js", "distill-post.js"),
    stylesheet = "distill.css"
  )
}

in_header_includes <- function(site_config, metadata) {

  in_header <- c()

  # links
  links <- list()
  if (!is.null(metadata$url)) {
    links[[1]] <- tags$link(
      rel="cannonical",
      href = metadata$url
    )
  }

  # authors meta tags
  author_meta <- lapply(metadata$author, function(author) {
    if (!is.list(author) || is.null(author$name) || is.null(author$url))
      stop("author metadata must include name and url fields", call. = FALSE)
    tags$meta(name="article:author", content=author$name)
  })


  # article meta (https://schema.org/Article)
  article_meta <- list()
  if (!is.null(metadata$date)) {
    date <- format.Date(metadata$date, "%Y-%m-%d")
    article_meta <- tagList(
      HTML("<!--  https://schema.org/Article -->"),
      tags$meta(property="description", itemprop="description", content=metadata$description),
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

  # render head tags
  meta_tags <- do.call(tagList, list(
    links,
    HTML(''),
    article_meta,
    updated_meta,
    author_meta,
    HTML(''),
    open_graph_meta,
    HTML(''),
    twitter_card_meta
  ))
  meta_html <- as.character(meta_tags)
  meta_file <- tempfile(fileext = "html")
  writeLines(meta_html, meta_file)
  in_header <- c(in_header, meta_file)

  # write front-matter into script tag
  front_matter_tag <- c(
    '<d-front-matter>',
    '<script id="distill-front-matter" type="text/json">',
    front_matter_from_metadata(metadata),
    '</script>',
    '</d-front-matter>'
  )
  front_matter_file <- tempfile(fileext = "html")
  writeLines(front_matter_tag, front_matter_file)
  in_header <- c(in_header, front_matter_file)

  in_header

}

open_graph_metadata <- function(site_config, metadata) {

  # core descriptors
  open_graph_meta <- list(
    HTML("<!--  https://developers.facebook.com/docs/sharing/webmasters#markup -->"),
    tags$meta(property = "og:type", content = "article"),
    tags$meta(property = "og:description", content = metadata$description)
  )

  # add a property
  add_open_graph_meta <- function(property, content) {
    open_graph_meta[[length(open_graph_meta)+1]] <<-
      tags$meta(property = property, content = content)
  }

  # cannonical url
  if (!is.null(metadata$url))
    add_open_graph_meta("og:url", metadata$url)

  # preivew/thumbnail url
  if (!is.null(metadata$preview))
    add_open_graph_meta("og:image", metadata$preview)

  # locale
  locale <- if (!is.null(metadata$locale))
    metadata$locale
  else if (!is.null(site_config$locale))
    site_config$locale
  else
    "en_US"
  add_open_graph_meta("og:locale", locale)

  # site name
  site_name <- if (!is.null(site_config$title))
    site_config$title
  else if (!is.null(site_config$navbar) && !is.null(site_config$navbar$title))
    site_config$navbar$title
  else
    NULL
  if (!is.null(site_name))
    add_open_graph_meta("og:site_name", site_name)

  open_graph_meta
}

twitter_card_metadata <- function(site_config, metadata) {

  twitter_card_meta <- list(
    HTML("<!--  https://dev.twitter.com/cards/types/summary -->")
  )

  # add a property
  add_twitter_card_meta <- function(property, content) {
    twitter_card_meta[[length(twitter_card_meta)+1]] <<-
      tags$meta(property = property, content = content)
  }

  # card type
  card_type <- if(!is.null(metadata$preview)) "summary_large_image" else "summary"
  add_twitter_card_meta("twitter:card", card_type)

  # title and description
  add_twitter_card_meta("twitter:title", metadata$title)
  add_twitter_card_meta("twitter:description", metadata$description)

  # cannonical url
  if (!is.null(metadata$url))
    add_twitter_card_meta("twitter:url", metadata$url)

  # preview image
  if (!is.null(metadata$preview)) {
    add_twitter_card_meta("twitter:image", metadata$preview)
    if (file.exists(metadata$preview) && is_file_type(metadata$preview, "png")) {
      png <- png::readPNG(metadata$preview)
      add_twitter_card_meta("twitter:image:width", ncol(png))
      add_twitter_card_meta("twitter:image:height", nrow(png))
    }
  }

  twitter_card_meta
}


before_body_includes <- function(site_config, metadata) {

  before_body <- c()

  before_body
}


after_body_includes <- function(site_config, metadata) {

  after_body <- c()

  # write bibliography after body
  if (!is.null(metadata$bibliography)) {
    bibliography_file <-  tempfile(fileext = "html")
    writeLines(c(
      '<d-bibliography>',
      '<script type="text/bibtex">',
      readLines(metadata$bibliography, warn = FALSE),
      '</script>',
      '</d-bibliography>'
    ), con = bibliography_file)
    after_body <- c(after_body, bibliography_file)
  }

  after_body
}

front_matter_from_metadata <- function(metadata) {
  front_matter <- list()
  front_matter$title <- metadata$title
  front_matter$description <- metadata$description
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
  jsonlite::toJSON(front_matter, auto_unbox = TRUE)
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

knitr_chunk_hook <- function(x, options) {
  if (is.null(options$layout))
    options$layout <- "l-body"
  paste0(
    '<div class="layout-chunk ', options$layout, '">',
    x,
    '</div>'
  )
}

block_class = function(x){
  if (length(x) == 0) return()
  classes = unlist(strsplit(x, '\\s+'))
  .classes = paste0('.', classes, collapse = ' ')
  paste0('{', .classes, '}')
}

parse_date <- function(date) {
  if (!is.null(date)) {
    parsed_date <- lubridate::mdy(date, tz = Sys.timezone(), quiet = TRUE)
    if (lubridate::is.POSIXct(parsed_date))
      date <- parsed_date
  }
  date
}

date_as_iso_8601 <- function(date) {
  format.Date(date, "%Y-%m-%dT00:00:00.000%z")
}

is_file_type <- function(file, type) {
  identical(tolower(tools::file_ext(file)), type)
}







