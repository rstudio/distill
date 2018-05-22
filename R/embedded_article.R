


radix_embedded_article <- function(self_contained = FALSE, lib_dir = NULL) {

  # build pandoc args
  args <- c("--standalone")

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(radix_resource("embedded.html")))

  post_knit <- function(metadata, input_file, runtime, encoding, ...) {

    args <- c()

    # get referenced article and create pandoc variable for it
    article <- metadata$article
    article_src <- file.path(article, "index.html")
    args <- c(args, pandoc_variable_arg("embedded-article-src", article_src))

    # derive metadata from article
    metadata$title <- "Embedded Article"

    # TODO: derive metadata

    # get site config
    site_config <- site_config(input_file, encoding)
    if (is.null(site_config))
      site_config <- list()

    # transform configuration
    c(site_config, metadata, args) %<-% transform_configuration(site_config, metadata, args)

    # html dependencies
    knitr::knit_meta_add(list(
      html_dependency_jquery(),
      html_dependency_iframe_resizer("host")
    ))

    # navigation includes
    args <- c(args,  pandoc_include_args(
      in_header = navigation_in_header(input_dir, site_config, metadata),
      before_body = navigation_before_body(input_dir, site_config, metadata),
      after_body = navigation_after_body(input_dir, site_config, metadata)
    ))


    # return args
    args
  }

  # return format
  output_format(
    knitr = knitr_options(),
    pandoc = pandoc_options(to = "html5", args = args),
    post_knit = post_knit,
    base_format = html_document_base(
      self_contained = self_contained,
      lib_dir = lib_dir
    )
  )

}



