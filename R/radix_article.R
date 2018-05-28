

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

  # build pandoc args
  args <- c("--standalone")

  # prevent highlighting
  args <- c(args, "--no-highlight")

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(radix_resource("default.html")))

  # lua filter
  if (pandoc_version() >= "2.0") {
    args <- c(args, "--lua-filter",
              pandoc_path_arg(radix_resource("distill.lua")))
  }

  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # shared variables (will be set by pre_knit)
  encoding <- NULL
  site_config <- NULL

  # pre-knit
  pre_knit <- function(input, encoding, ...) {

    # update encoding
    encoding <<- encoding

    # get site config
    site_config <<- find_site_config(input, encoding)
    if (is.null(site_config))
      site_config <<- list()

    # merge selected options from site config (as in the case where we
    # are in a collection rmarkdown wouldn't have picked up _site options)
    if (!is.null(site_config[["output"]])) {

      site_options <- site_config[["output"]][["radix::radix_article"]]

      # establish mergeable options
      user_options <- list()
      user_options$fig_width <- fig_width
      user_options$fig_height <- fig_height
      user_options$fig_retina <- fig_retina
      user_options$dev <- dev

      # do the merge
      format_options <- merge_output_options(site_options, user_options)

      # assign back to options
      fig_width <<- format_options$fig_width
      fig_height <<- format_options$fig_height
      fig_retina <<- format_options$fig_retina
      dev <<- format_options$dev
    }

    # establish knitr options
    knitr_options <- knitr_options_html(fig_width = fig_width,
                                        fig_height = fig_height,
                                        fig_retina = fig_retina,
                                        keep_md = keep_md,
                                        dev = dev)
    knitr_options$opts_chunk$echo <- FALSE
    knitr_options$opts_chunk$warning <- FALSE
    knitr_options$opts_chunk$message <- FALSE
    knitr_options$opts_chunk$comment <= NA
    knitr_options$knit_hooks <- list()
    knitr_options$knit_hooks$source <- knitr_source_hook
    knitr_options$knit_hooks$chunk <- knitr_chunk_hook()

    structure(knitr_options, class = "knitr_options")
  }

  # post-knit
  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    # pandoc args
    args <- c()

    # site level css
    args <- c(args, site_css_as_placeholder(site_config))

    # additional user css
    for (css_file in css)
      args <- c(args, "--css", pandoc_path_arg(css_file))

    # metadata to json (do this before transforming)
    metadata_json <- embedded_metadata(metadata)

    # transform configuration
    c(site_config, metadata) %<-% transform_configuration(site_config, metadata)

    # add title-prefix if necessary
    if (!is.null(metadata$title_prefix))
      args <- c(args, "--title-prefix", metadata$title_prefix)

    # add html dependencies
    knitr::knit_meta_add(list(
      html_dependency_jquery(),
      html_dependency_bowser(),
      html_dependency_headroom(),
      html_dependency_webcomponents(),
      html_dependency_distill()
    ))

    # header includes: radix then user
    in_header <- c(metadata_in_header(site_config, metadata),
                   metadata_json,
                   navigation_in_header_file(site_config),
                   includes$in_header)

    # before body includes: radix then user
    before_body <- c(front_matter_before_body(site_config, metadata),
                     navigation_before_body_file(site_config),
                     includes$before_body)

    # after body includes: user then radix
    after_body <- c(includes$after_body,
                    appendices_after_body(input_file, metadata),
                    navigation_after_body_file(find_site_dir(input_file), site_config))

    # populate args
    args <- c(args,  pandoc_include_args(
      in_header = in_header,
      before_body = before_body,
      after_body = after_body
    ))

    # return args
    args

  }

  # return format
  output_format(
    knitr = knitr_options(),
    pandoc = pandoc_options(to = "html5",
                            from = from_rmarkdown(fig_caption, md_extensions),
                            args = args),
    keep_md = keep_md,
    clean_supporting = self_contained,
    pre_knit = pre_knit,
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


# find the site config for an input file (recognize sites for Rmds in collections)
find_site_config <- function(input_file, encoding) {

  # look for the default based on an Rmd at the top level
  config <- site_config(input_file, encoding)
  if (is.null(config)) {

    # look for a site dir in a parent
    site_dir <- find_site_dir(input_file)

    if(!is.null(site_dir)) {

      # get the site config
      config <- site_config(site_dir, encoding)

      # check for collections
      collections <- site_collections(site_dir, config)

      # compute relative path
      input_file_relative <- rmarkdown::relative_to(
        normalize_path(site_dir),
        normalize_path(input_file)
      )

      # is this file within one of our collections?
      in_collection <- any(startsWith(input_file_relative, paste0(collections, "/")))
      if (in_collection) {
        # offset config
        offset <- collection_file_offset(input_file_relative)
        config <- offset_site_config(site_dir, config, offset)
      } else {
        config <- NULL
      }
    }
  }

  # return config
  config
}

site_criterion <- rprojroot::has_file("_site.yml")

find_site_dir <- function(input_file) {
  tryCatch(
    rprojroot::find_root(
      criterion = site_criterion,
      path = dirname(input_file)
    ),
    error = function(e) NULL
  )
}

offset_site_config <- function(site_dir, config, offset) {

  # capture original output dir
  output_dir <- config$output_dir

  # update file references
  config <- rapply(config, how = "replace", classes = c("character"),
                   function(x) {
                     if (file.exists(file.path(site_dir, x))) {
                       file.path(offset, x)
                     } else {
                       x
                     }
                   }
  )

  # preserve output_dir
  config$output_dir <- output_dir

  # provide offset as attribute
  attr(config, "offset") <- offset

  config
}



# hook to ensure newline at the beginning of chunks (workaround distill.js bug)
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
      padding, '<div class="layout-chunk ', options$layout, '">\n',
      output, '\n',
      padding, '\n',
      padding, '</div>\n'
    )
  }
}


site_css_as_placeholder <- function(site_config) {
  c()
}







