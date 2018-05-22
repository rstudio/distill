


render_posts <- function(posts_dir, encoding = getOption("encoding")) {



}


render_post <- function(post_dir, encoding = getOption("encoding")) {

  # get the site config
  site_config <- site_config(encoding = encoding)

  # get the target Rmd and html
  post_rmd <- discover_post_rmd(post_dir, encoding)
  if (is.null(post_rmd))
    stop("No radix_article found in ", post_dir, call. = FALSE)
  post_html <- file_with_ext(post_rmd, "html")

  # determine location of target output dir
  posts_output_dir <- file.path(site_config$output_dir, "posts")
  post_output_dir <- file.path(posts_output_dir, basename(post_dir))
  post_output_src_dir <- file.path(post_output_dir, "src")
  post_output_src_html <- file.path(post_output_src_dir, basename(post_html))

  # see if we need to update the post content
  if (!file.exists(post_output_src_html) ||
      file.info(post_output_src_html)$mtime != file.info(post_html)$mtime) {

    # remove and recreate the post directory
    if (dir_exists(post_output_src_dir))
      unlink(post_output_src_dir, recursive = TRUE)
    dir.create(post_output_src_dir, recursive = TRUE)

    # copy appropriate files into the post directory
    resources <- yaml_front_matter(post_rmd, encoding)$resources
    if (!is.null(resources))
      c(include, exclude) %<-% list(resources$include, resources$exclude)
    else
      c(include, exclude) %<-% list(NULL, NULL)
    post_resources <- site_resources(
      site_dir = post_dir,
      include = include,
      exclude = exclude,
      encoding = encoding
    )
    file.copy(from = file.path(post_dir, post_resources),
              to = post_output_src_dir,
              recursive = TRUE,
              copy.date = TRUE)
  }


  # create posts/dir/
      # posts/dir/index.html with embed (supply lib versions)
      # posts/dir/front-matter.yaml with metadata

}


discover_post_rmd <- function(post_src_dir, encoding = getOption("encoding")) {

  post_rmd <- NULL

  all_rmds <- list.files(path = post_src_dir,
                         pattern = "^[^_].*\\.[Rr][Mm][Dd]$",
                         full.names = TRUE)

  if (length(all_rmds) == 1) {

    # just one R Markdown document
    post_rmd <- all_rmds

  } else {

    # more than one: look for an index
    index <- which(tolower(all_rmds) == file.path(post_src_dir, "index.rmd"))
    if (length(index) > 0) {
      post_rmd <- all_rmds[index[1]]
    }

    # look for first one that has radix_article as a default format
    else {
      for (rmd in all_rmds) {
        format <- rmarkdown::default_output_format(rmd, encoding)
        if (format$name == "radix::radix_article") {
          post_rmd <- rmd
          break
        }
      }
    }
  }

  post_rmd

}







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
      html_dependency_iframe_resizer()
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



