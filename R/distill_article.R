

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
  knitr_options$knit_hooks$source  <- function(x, options) {

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

  # hook to apply distill.layout
  knitr_options$knit_hooks$chunk  <- function(x, options) {
    if (is.null(options$distill.layout))
      options$distill.layout <- "l-body"
    paste0(
      '<div class="distill-layout-chunk ', options$distill.layout, '">',
      x,
      '</div>'
    )
  }

  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    # extra args
    args <- c()

    # get site_config and generate additional header/footer html
    config <- site_config(input_file, encoding)
    args <- c(args, include_args_from_site_config(config, runtime))

    # return args
    args
  }

  # preprocessor
  pre_processor <- function (metadata, input_file, runtime, knit_meta,
                             files_dir, output_dir) {

    args <- c()

    # files to write into the header/footer
    in_header <- c()
    after_body <- c()

    # write front-matter into script tag
    front_matter <- c(
      '<d-front-matter>',
      '<script id="distill-front-matter" type="text/json">',
      jsonlite::toJSON(list(
        title = metadata$title,
        description = metadata$description,
        authors = if (is.null(metadata$authors)) list() else metadata$authors
      ), auto_unbox = TRUE),
      '</script>',
      '</d-front-matter>'
    )
    front_matter_file <- tempfile(fileext = "html")
    writeLines(front_matter, front_matter_file)
    in_header <- c(in_header, front_matter_file)

    # write distill_metadata into script tag
    distill_data <- c(
      '<script type="text/javascript">',
      'window.distill_data = {',
      # TODO: draw date from document metadata
      # sprintf('  publishedDate: new Date("%s")', '2016-09-08T07:00:00.000Z'),
      '};',
      '</script>'
    )
    distill_data_file <- tempfile(fileext = "html")
    writeLines(distill_data, distill_data_file)
    in_header <- c(in_header, distill_data_file)

    # write bibliography into tag
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


    # include files in the header
    args <- c(args, pandoc_include_args(in_header = in_header, after_body = after_body))

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

include_args_from_site_config <- function(config, runtime) {

  includes <- list(
    in_header = NULL,
    before_body = NULL,
    after_body = NULL
  )

  includes_to_pandoc_args(includes,
                          filter = if (is_shiny_classic(runtime))
                            function(x) normalize_path(x, mustWork = FALSE)
                          else
                            identity)
}


block_class = function(x){
  if (length(x) == 0) return()
  classes = unlist(strsplit(x, '\\s+'))
  .classes = paste0('.', classes, collapse = ' ')
  paste0('{', .classes, '}')
}






