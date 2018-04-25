

#'
#' @import rmarkdown
#'
#' @export
distill_article <- function(fig_width = 7,
                            fig_height = 5,
                            fig_retina = 2,
                            fig_caption = TRUE,
                            dev = "png",
                            df_print = "paged",
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

  # use section divs
  args <- c(args, "--section-divs")

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
  args <- c(args, "--lua-filter",
            pandoc_path_arg(resource("distill-1.0/distill.lua")))

  # use link citations (so we can do citation conversion)
  args <- c(args, "--metadata=link-citations:true")

  # html dependency for distill
  extra_dependencies <- append(extra_dependencies,
                               list(html_dependency_jquery(),
                                    html_dependency_distill()))

  # pagedtables
  if (identical(df_print, "paged")) {
    extra_dependencies <- append(extra_dependencies,
                                 list(html_dependency_pagedtable()))

  }

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

  # hook to record fig.layout
  knitr_options$knit_hooks <- list()
  knitr_options$knit_hooks$chunk  <- function(x, options) {
    if (!is.null(options$fig.layout)) {
      paste0(
        '<div class="fig-layout-chunk ', options$fig.layout,
        '" data-fig-layout="', options$fig.layout, '">',
        x,
        '</div>'
      )
    } else {
      x
    }
  }

  # preprocessor
  pre_processor <- function (metadata, input_file, runtime, knit_meta,
                             files_dir, output_dir) {

    args <- c()

    # files to write into the header
    in_header <- c()

    # write front-matter into script tag
    front_matter <- c(
      '<script type="text/front-matter">',
      yaml::as.yaml(list(
        title = metadata$title,
        description = metadata$description,
        authors = metadata$authors,
        affiliations = metadata$affiliations
      )),
      '</script>'
    )
    front_matter_file <- tempfile(fileext = "html")
    writeLines(front_matter, front_matter_file)
    in_header <- c(in_header, front_matter_file)

    # write bibliography into script tag
    if (!is.null(metadata$bibliography)) {
      bibliography_file <-  tempfile(fileext = "html")
      writeLines(c(
        '<script type="text/bibliography">',
        readLines(metadata$bibliography, warn = FALSE),
        '</script>'
      ), con = bibliography_file)
    }
    in_header <- c(in_header, bibliography_file)

    # include files in the header
    args <- c(args, pandoc_include_args(in_header = in_header))

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
    version = "1.0",
    src = system.file("rmarkdown/templates/distill_article/resources/distill-1.0",
                      package = "distill"),
    script = c("distill.js", "template.v1.js"),
    stylesheet = "distill.css"
  )
}


