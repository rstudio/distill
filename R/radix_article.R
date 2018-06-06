

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

  # validate that we have pandoc 2
  validate_pandoc_version()

  # build pandoc args
  args <- c("--standalone")

  # prevent highlighting
  args <- c(args, "--no-highlight")

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(radix_resource("default.html")))

  # lua filter
  args <- c(args, "--lua-filter",
            pandoc_path_arg(radix_resource("distill.lua")))

  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # establish knitr options
  knitr_options <- knitr_options_html(fig_width = fig_width,
                                      fig_height = fig_height,
                                      fig_retina = fig_retina,
                                      keep_md = keep_md,
                                      dev = dev)
  knitr_options$opts_chunk$echo <- FALSE
  knitr_options$opts_chunk$warning <- FALSE
  knitr_options$opts_chunk$message <- FALSE
  knitr_options$opts_chunk$comment <- NA
  knitr_options$opts_chunk$R.options <- list(width = 70)
  knitr_options$opts_hooks <- list()
  knitr_options$opts_hooks$preview <- knitr_preview_hook
  knitr_options$knit_hooks <- list()
  knitr_options$knit_hooks$chunk <- knitr_chunk_hook()

  # shared site_config
  site_config <- NULL

  # post-knit
  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    # pandoc args
    args <- c()

    # additional user css
    for (css_file in css)
      args <- c(args, "--css", pandoc_path_arg(css_file))

    # compute knitr output file
    output_file <- file_with_meta_ext(input_file, "knit", "md")

    # metadata to json (do this before transforming)
    metadata_json <- embedded_metadata(metadata)

    site_config <<- site_config(input_file, encoding)
    if (is.null(site_config))
      site_config <<- list()

    # transform configuration
    c(site_config, metadata) %<-% transform_configuration(
      file = output_file,
      site_config = site_config,
      collection_config = NULL,
      metadata = metadata,
      auto_preview = !self_contained
    )

    # if this is a listing then set the layout variable
    if (!is.null(metadata$listing))
      args <- c(args, pandoc_variable_arg("layout", "listing"))

    # add html dependencies
    knitr::knit_meta_add(list(
      html_dependency_jquery(),
      html_dependency_bowser(),
      html_dependency_webcomponents(),
      html_dependency_distill()
    ))

    # add navbar related dependencies
    ensure_navbar_dependencies(site_config, dirname(input_file))

    # header includes: radix then user
    in_header <- c(metadata_in_header(site_config, metadata, self_contained),
                   citation_references_in_header(input_file, metadata$bibliography),
                   metadata_json,
                   manifest_in_header(site_config, input_file, metadata),
                   navigation_in_header_file(site_config))

    # before body includes: radix then user
    before_body <- c(front_matter_before_body(metadata),
                     navigation_before_body_file(site_config),
                     site_before_body_file(site_config),
                     includes$before_body,
                     listing_before_body(metadata))

    # after body includes: user then radix
    after_body <- c(includes$after_body,
                    site_after_body_file(site_config),
                    appendices_after_body_file(site_config, metadata),
                    navigation_after_body_file(dirname(input_file), site_config))

    # populate args
    args <- c(args,  pandoc_include_args(
      in_header = in_header,
      before_body = before_body,
      after_body = after_body
    ))

    # return args
    args

  }

  pre_processor <- function(yaml_front_matter, utf8_input, runtime, knit_meta,
                            files_dir, output_dir, ...) {
    pandoc_include_args(in_header = c(site_in_header_file(site_config),
                                      includes$in_header))
  }

  # return format
  output_format(
    knitr = knitr_options,
    pandoc = pandoc_options(to = "html5",
                            from = from_rmarkdown(fig_caption, md_extensions),
                            args = args),
    keep_md = keep_md,
    clean_supporting = self_contained,
    post_knit = post_knit,
    pre_processor = pre_processor,
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


knitr_preview_hook <- function(options) {
  if (isTRUE(options$preview))
    options$out.extra <- c(options$out.extra, "data-radix-preview=1")
  options
}

# hook to enclose output in div with layout class
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
      padding, '<div class="layout-chunk" data-layout="', options$layout, '">\n',
      output, '\n',
      padding, '\n',
      padding, '</div>\n'
    )
  }
}


validate_pandoc_version <- function() {
  if (!pandoc_available("2.0")) {
    msg <-
      if (!is.null(rstudio_version())) {
        msg <- paste("Radix requires RStudio v1.2 or greater.",
                     "Please update at:",
                     "https://www.rstudio.com/rstudio/download/preview/")
      } else {
        msg <- paste("Radix requires Pandoc v2.0 or greator.",
                     "Please update at:",
                      "https://github.com/jgm/pandoc/releases/latest")
      }
    stop(msg, call. = FALSE)
  }
}



