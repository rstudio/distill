

#' R Markdown format for Distill articles
#'
#' Scientific and technical writing, native to the web.
#'
#' Distill articles feature attractive, reader-friendly typography, flexible
#' layout options for visualizations, and full support for footnotes and
#' citations.
#'
#' @inheritParams rmarkdown::html_document
#'
#' @param css CSS and/or Sass files to include. Files with an extension of `.sass` or
#'  `.scss` are compiled to CSS via `sass::sass()`.
#' @param toc_float Float the table of contents to the left when the article
#'   is displayed at widths > 1000px. If set to `FALSE` or the width is less
#'   than 1000px the table of contents will be placed above the article body.
#' @param smart Produce typographically correct output, converting straight
#'   quotes to curly quotes, `---` to em-dashes, `--` to en-dashes, and
#'   `...` to ellipses.
#' @param code_folding Include code blocks hidden, and allow users to
#'   optionally display the code by clicking a "Show code" button just above
#'   the output. Pass a character vector to customize the text of the
#'   "Show code" button. You can also specify `code_folding` as chunk option
#'   for per-chunk folding behavior.
#' @param highlight Syntax highlighting style. Supported styles include
#'   "default", "rstudio", "tango", "pygments", "kate", "monochrome", "espresso",
#'   "zenburn", "breezedark", and  "haddock". Pass NULL to prevent syntax
#'   highlighting.
#' @param highlight_downlit Use the \pkg{downlit} package to highlight
#'   R code (including providing hyperlinks to function documentation).
#' @param theme CSS file with theme variable definitions
#'
#' @import rmarkdown
#' @import htmltools
#' @import downlit
#'
#' @export
distill_article <- function(toc = FALSE,
                          toc_depth = 3,
                          toc_float = TRUE,
                          fig_width = 6.5,
                          fig_height = 4,
                          fig_retina = 2,
                          fig_caption = TRUE,
                          dev = "png",
                          smart = TRUE,
                          code_folding = FALSE,
                          self_contained = TRUE,
                          highlight = "default",
                          highlight_downlit = TRUE,
                          mathjax = "default",
                          extra_dependencies = NULL,
                          theme = NULL,
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

  # table of contents
  args <- c(args, pandoc_toc_args(toc, toc_depth))

  # toc_float
  if (toc_float) {
    args <- c(args, pandoc_variable_arg("toc-float", "1"))
  }

  # add highlighting
  args <- c(args, distill_highlighting_args(highlight))

  # turn off downlit if there is no highlighting at all
  if (is.null(highlight))
    highlight_downlit <- FALSE

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(distill_resource("default.html")))


  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # establish knitr options
  knitr_options <- knitr_options_html(fig_width = fig_width,
                                      fig_height = fig_height,
                                      fig_retina = fig_retina,
                                      keep_md = keep_md,
                                      dev = dev)
  knitr_options$opts_chunk$echo <- identical(code_folding, FALSE)
  knitr_options$opts_chunk$warning <- FALSE
  knitr_options$opts_chunk$message <- FALSE
  knitr_options$opts_chunk$comment <- NA
  knitr_options$opts_chunk$R.options <- list(width = 70)
  knitr_options$opts_chunk$code_folding <- code_folding
  knitr_options$opts_knit$bookdown.internal.label <- TRUE
  knitr_options$opts_hooks <- list()
  knitr_options$opts_hooks$preview <- knitr_preview_hook
  knitr_options$opts_hooks$code_folding <- function(options) {
    if (!identical(options$code_folding, FALSE)) {
      options[["echo"]] <- TRUE
    }
    options
  }
  knitr_options$knit_hooks <- knit_hooks(downlit = highlight_downlit)

  # shared variables
  site_config <- NULL
  encoding <- NULL

  # metadata_includes are includes derived from this file's metadata
  # (as opposed to site level includes which we already process)
  metadata_includes <- list()

  # post-knit
  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    # save encoding
    encoding <<- encoding

    # run R code in metadata
    metadata <- eval_metadata(metadata)

    # determine metadata_includes
    metadata_output <- metadata[["output"]]
    if (is.list(metadata_output)) {
      metadata_distill <- metadata_output[["distill::distill_article"]]
      if (is.list(metadata_distill)) {
        metadata_includes <<- metadata_distill[["includes"]]
      }
    }

    # pandoc args
    args <- c()

    # compute knitr output file
    output_file <- file_with_meta_ext(input_file, "knit", "md")

    # normalize site config and see if we are in a collection
    in_collection <- FALSE
    site_config <<- site_config(input_file, encoding)
    if (is.null(site_config)) {

      # default site_config to empty
      site_config <<- list()

      # set in_collection flag
      in_collection <- !is.null(find_site_dir(input_file))
    }

    # provide a default date of today for in_collection
    if (is.null(metadata[["date"]]) && in_collection) {
      metadata$date <- date_today()
      args <- c(args, pandoc_variable_arg("date", metadata$date))
    }

    # make copy of metdata before transforming
    embedable_metadata <- metadata

    # fixup author for embedding
    embedable_metadata$author <- fixup_author(embedable_metadata$author)

    # transform configuration
    transformed <-  transform_configuration(
      file = output_file,
      site_config = site_config,
      collection_config = NULL,
      metadata = metadata,
      auto_preview = !self_contained
    )
    site_config <- transformed$site_config
    metadata <- transformed$metadata

    # pickup canonical and citation urls
    embedable_metadata$citation_url <- embedable_metadata$citation_url
    embedable_metadata$canonical_url <- embedable_metadata$canonical_url

    # create metadata json
    metadata_json <- embedded_metadata(embedable_metadata)

    # list of html dependencies (if we navigation then we get jquery
    # from site dependencies so don't include it here)
    html_deps <- list()
    if (!have_navigation(site_config)) {
      html_deps <- list(html_dependency_jquery())
    } else {
      html_deps <- list()
    }
    html_deps <- append(html_deps, list(
      html_dependency_popper(),
      html_dependency_tippy(),
      html_dependency_anchor(),
      html_dependency_bowser(),
      html_dependency_webcomponents(),
      html_dependency_distill()
    ))

    # resolve listing
    listing <- list()

    # special handling for listing pages
    if (!is.null(metadata$listing)) {
      # can be either a character vector with a collection name or a list
      # of articles by collection
      if (is.list(metadata$listing))
        listing <- resolve_yaml_listing(input_file, site_config, metadata, metadata$listing)
      else
        listing <- resolve_listing(input_file, site_config, metadata)
    }

    if (length(listing) > 0) {
      # indicate we are are using a listing layout
      args <- c(args, pandoc_variable_arg("layout", "listing"))

      # forward feed_url if we generated a feed
      if (!is.null(listing$feed))
        args <- c(args,
                  pandoc_variable_arg("feed", url_path(site_config$base_url, listing$feed))
        )
    }

    # add html dependencies
    knitr::knit_meta_add(html_deps)

    # add site related dependencies
    ensure_site_dependencies(site_config, dirname(input_file))

    # resolve theme from site if it's not specified in the article
    if ((is.null(theme) || !file.exists(theme))) {
      theme <- theme_from_site_config(find_site_dir(input_file), site_config)
    }

    # header includes: distill then user
    in_header <- c(metadata_in_header(site_config, metadata, self_contained),
                   citation_references_in_header(input_file, metadata$bibliography),
                   metadata_json,
                   manifest_in_header(site_config, input_file, metadata, self_contained),
                   navigation_in_header_file(site_config),
                   distill_in_header_file(theme))

    # before body includes: distill then user
    before_body <- c(front_matter_before_body(metadata),
                     navigation_before_body_file(dirname(input_file), site_config),
                     site_before_body_file(site_config),
                     metadata_includes$before_body,
                     listing$html)

    # after body includes: user then distill
    after_body <- c(metadata_includes$after_body,
                    site_after_body_file(site_config),
                    appendices_after_body_file(input_file, site_config, metadata),
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
                                      metadata_includes$in_header))
  }

  on_exit <- function() {
    validate_rstudio_version()
  }

  # do not wrap lines:
  # https://github.com/rstudio/bookdown/issues/504
  # https://github.com/rstudio/distill/issues/463
  if (pandoc_available("2.0") && !length(grep('--wrap', pandoc_args))) {
    pandoc_args <- c('--wrap', 'preserve', pandoc_args)
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
    post_processor = distill_article_post_processor(function() encoding, self_contained),
    on_exit = on_exit,
    base_format = html_document_base(
      smart = smart,
      self_contained = self_contained,
      lib_dir = lib_dir,
      css = css,
      mathjax = mathjax,
      template = "default",
      pandoc_args = pandoc_args,
      bootstrap_compatible = FALSE,
      extra_dependencies = extra_dependencies,
      ...
    )
  )
}

distill_highlighting_args <- function(highlight) {

  # The default highlighting is a custom pandoc theme based on
  # https://github.com/ericwbailey/a11y-syntax-highlighting
  # It's in a JSON theme file as described here:
  #
  #   https://pandoc.org/MANUAL.html#syntax-highlighting
  #
  # To create the theme we started with pandoc --print-highlight-style haddock
  # (since that was the closest pandoc them to textmate) then made
  # the following changes to create the RStudio textmate version:
  #
  #  https://github.com/rstudio/distill/compare/02b241083b8ca5cda90954c6c37e9f11bf830b2c...13fb0f6b34e9d04df0bd24a02980e29105a8f68d#diff-f088084fe658ee281215b486b2f18dab
  #
  # all available pandoc highlighting tokens are enumerated here:
  #
  #   https://github.com/jgm/skylighting/blob/a1d02a0db6260c73aaf04aae2e6e18b569caacdc/skylighting-core/src/Skylighting/Format/HTML.hs#L117-L147
  #
  default <- distill_resource("arrow.theme")

  # if it's "rstudio", then use an embedded theme file
  if (identical(highlight, "rstudio")) {
    highlight <- distill_resource("rstudio.theme")
  }

  rmarkdown::pandoc_highlight_args(highlight, default)
}

knitr_preview_hook <- function(options) {
  if (isTRUE(options$preview))
    options$out.extra <- c(options$out.extra, "data-distill-preview=1")
  options
}

knit_hooks <- function(downlit) {

  # capture the default chunk and source hooks
  previous_hooks <- knitr::knit_hooks$get()
  on.exit(knitr::knit_hooks$restore(previous_hooks), add = TRUE)
  knitr::render_markdown()
  default_chunk_hook <- knitr::knit_hooks$get("chunk")
  default_source_hook <- knitr::knit_hooks$get("source")

  # apply chunk hook
  hooks <- list(
    chunk = function(x, options) {
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
  )

  # source hook to do downlit processing and code_folding
  hooks$source <- function(x, options) {

    code_folding <- not_null(options[["code_folding"]], FALSE)

    if (downlit && options$engine == "R") {
      code <- highlight(paste0(x, "\n", collapse = ""),
                        classes_pandoc(),
                        pre_class = NULL)
      if (is.na(code)) {
        x <- default_source_hook(x, options)
      } else {
        x <- paste0("<div class=\"sourceCode\">",
                    "<pre class=\"sourceCode r\">",
                    "<code class=\"sourceCode r\">",
                    code,
                    "</code></pre></div>")
        x <- paste0(x, "\n")
      }
    } else {
      x <- default_source_hook(x, options)
    }

    if (!identical(code_folding, FALSE)) {
      if (identical(code_folding, TRUE)) {
        code_folding <- "Show code"
      } else {
        code_folding <- as.character(code_folding)
      }
      x <- paste0("<details>\n<summary>", code_folding ,"</summary>\n", x, "\n</details>")
    }

    x
  }

  if (downlit) {
    # document hook to inject a fake empty code block a the end of the
    # document (to force pandoc to including highlighting cssm which it
    # might not do if all chunks are handled by downlit)
    hooks$document <- function(x, options) {
      c(x, "```{.r .distill-force-highlighting-css}", "```")
    }
  }

  # return hooks
  hooks
}


validate_pandoc_version <- function() {
  if (!pandoc_available("2.0")) {
    msg <-
      if (!is.null(rstudio_version())) {
        msg <- paste("Distill requires RStudio v1.2 or greater.",
                     "Please update at:",
                     "https://posit.co/downloads/")
      } else {
        msg <- paste("Distill requires Pandoc v2.0 or greater",
                     "Please update at:",
                      "https://github.com/jgm/pandoc/releases/latest")
      }
    stop(msg, call. = FALSE)
  }
}


distill_in_header <- function(theme = NULL) {
  doRenderTags(distill_in_header_html(theme))
}

distill_in_header_file <- function(theme = NULL) {
  html_file(distill_in_header_html(theme))
}

distill_in_header_html <- function(theme = NULL) {
  distill_html <- html_from_file(
    system.file("rmarkdown/templates/distill_article/resources/distill.html",
                package = "distill")
  )
  theme_html <- theme_in_header_html(theme)
  placeholder_html("distill", distill_html, theme_html)
}

theme_in_header_html <- function(theme) {
  if (!is.null(theme)) {
    tagList(
      includeCSS(distill_resource("base-variables.css")),
      includeCSS(theme),
      includeCSS(distill_resource("base-style.css"))
    )
  } else {
    NULL
  }
}

theme_in_header_file <- function(theme) {
  html_file(theme_in_header_html(theme))
}


