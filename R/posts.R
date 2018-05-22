


render_posts <- function(site_dir = ".", posts_dir = "_posts", encoding = getOption("encoding")) {

  lapply(list.dirs(posts_dir, full.names = TRUE, recursive = FALSE),
         function(post_dir) render_post(site_dir, post_dir, encoding))

  invisible(NULL)
}


render_post <- function(site_dir, post_dir, encoding = getOption("encoding")) {

  # get the site config and metadata
  site_config <- site_config(input = site_dir, encoding = encoding)

  # get the parent post dir
  posts_dir <- dirname(post_dir)
  posts_name <- sub("^_", "", basename(posts_dir))

  # get the target Rmd and html
  post_rmd <- discover_post_rmd(post_dir, encoding)
  if (is.null(post_rmd))
    stop("No radix_article found in ", post_dir, call. = FALSE)
  post_html <- file_with_ext(post_rmd, "html")

  # get the target front matter / metadata
  front_matter <- yaml_front_matter(post_rmd, encoding)

  # determine location of target output dir
  posts_output_dir <- file.path(site_config$output_dir, posts_name)
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
    resources <- front_matter$resources
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

  # transform configuration
  c(site_config, metadata) %<-% transform_configuration(site_config, front_matter)

  # convert path references
  output_dir <- site_config$output_dir
  site_config <- transform_site_paths(site_config, site_dir, "../..")

  # build pandoc args
  args <- c("--standalone")

  # add template
  args <- c(args, "--template",
            pandoc_path_arg(radix_resource("embedded.html")))

  # forward title
  args <- c(args, "--metadata", paste0("pagetitle=", metadata$qualified_title))

  # js libraries for site frame
  jquery <- html_dependency_jquery()
  headroom <- html_dependency_headroom()
  iframe_resizer <- html_dependency_iframe_resizer()
  lapply(list(jquery, headroom, iframe_resizer), function (dependency) {
    htmltools::copyDependencyToDir(
      dependency,
      file.path(file.path(output_dir, "site_libs")))
  })
  args <- c(args,
    pandoc_variable_arg("jquery-version", jquery$version),
    pandoc_variable_arg("headroom-version", headroom$version),
    pandoc_variable_arg("iframe-resizer-version", iframe_resizer$version)
  )

  # embedded article
  args <- c(args,
    pandoc_variable_arg("embedded-article-src", file.path("src", basename(post_html)))
  )

  # includes
  in_header <- c(metadata_in_header(site_config, metadata),
                 navigation_in_header(site_config, metadata))

  before_body <- c(navigation_before_body(site_config, metadata))

  after_body <- c(navigation_after_body(site_dir, site_config, metadata))

  # populate args
  args <- c(args,  pandoc_include_args(
    in_header = in_header,
    before_body = before_body,
    after_body = after_body
  ))

  # pandoc convert
  input_tmp <- tempfile(fileext = "md")
  writeLines("", input_tmp)
  output_tmp <- tempfile(fileext = "html")
  pandoc_convert(
    input = input_tmp,
    from = "markdown_strict",
    to = "html5",
    output = output_tmp,
    options = args,
    verbose = TRUE
  )

  # copy to destination
  file.copy(output_tmp, file.path(post_output_dir, "index.html"))

  # write front-matter to src dir
  yaml::write_yaml(front_matter, file.path(post_output_src_dir, "metadata.yml"))
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

transform_site_paths <- function(site_config, site_dir, prefix) {
  if (!is.list(site_config))
    site_config <- list(site_config)
  rapply(site_config, how = "replace", classes = c("character"), function(x) {
    if (file.exists(file.path(site_dir, x))) {
      file.path(prefix, x)
    } else {
      x
    }
  })
}









