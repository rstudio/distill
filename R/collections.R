





render_collections <- function(site_dir, encoding = getOption("encoding"), quiet = FALSE) {

  # read site config
  config <- site_config(site_dir, encoding)

  # caching html generator
  navigation_html <- navigation_html_generator()

  for (collection in site_collections(site_dir, config)) {

    if (!quiet)
      cat(paste0("Rendering ", collection, ":\n"))

    # remove existing output dir if it exists
    collection_output <- file.path(site_dir, config$output_dir, sub("^_", "", collection))
    if (dir_exists(collection_output))
      unlink(collection_output, recursive = TRUE)

    # enumerate all directories within the collection
    collection_dirs <- list.files(file.path(site_dir, collection))

    # find all Rmd files (not beginning with _) within the collection
    rmd_files <- file.path(site_dir,
                           collection,
                           list.files(
                              file.path(site_dir, collection),
                              pattern = "^[^_].*\\.[Rr]md$",
                              recursive = TRUE
                           ))

    # render each rmd file
    for (rmd in rmd_files) {

      # resolve to radix article rmd (there can only be one per directory)
      rmd_directory <- dirname(rmd)
      rmd <- discover_collection_rmd(rmd_directory, encoding)

      # read metadata from rmd
      metadata <- yaml_front_matter(rmd, encoding)

      # bail if the rmd is unrendered
      if (!file.exists(file_with_ext(rmd, "html")))
        next

      # strip site_dir prefix
      rmd <- sub(paste0("^", site_dir, "/"), "", rmd)

      # compute offset
      offset <- collection_file_offset(rmd)

      # determine the target output dir
      output_dir <- file.path(site_dir, config$output_dir, sub("^_", "", dirname(rmd)))

      # bail if this is a draft
      if (isTRUE(metadata$draft))
        next

      # progress
      if (!quiet)
        cat(" ", rmd, "\n")

      # create the output directory
      dir.create(output_dir, recursive = TRUE)

      # copy files to output directory
      resources <- metadata$resources
      if (!is.null(resources))
        c(include, exclude) %<-% list(resources$include, resources$exclude)
      else
        c(include, exclude) %<-% list(NULL, NULL)
      rmd_resources <- site_resources(
        site_dir = rmd_directory,
        include = include,
        exclude = exclude,
        encoding = encoding
      )
      file.copy(from = file.path(rmd_directory, rmd_resources),
                to = output_dir,
                recursive = TRUE,
                copy.date = TRUE)

      # rename rmd.html to index.html
      rmd_html <- file.path(output_dir, file_with_ext(basename(rmd), "html"))
      index_html <- file.path(output_dir, "index.html")
      if (rmd_html != index_html)
        file.rename(rmd_html, index_html)

      # substitute navigation html
      navigation <- navigation_html(site_dir, config, offset)
      apply_navigation <- function(content, context) {
        begin_context <- paste0("<!--radix_navigation_", context, "-->")
        end_context <- paste0("<!--/radix_navigation_", context, "-->")
        pattern <- paste0(begin_context, ".*", end_context)
        sub(pattern, navigation[[context]], content, useBytes = TRUE)
      }
      index_content <- paste(readLines(index_html, encoding = "UTF-8"), collapse = "\n")
      index_content <- apply_navigation(index_content, "in_header")
      index_content <- apply_navigation(index_content, "before_body")
      index_content <- apply_navigation(index_content, "after_body")
      writeLines(index_content, index_html, useBytes = TRUE)
    }
  }
}


discover_collection_rmd <- function(collection_dir, encoding = getOption("encoding")) {

  collection_rmd <- NULL

  all_rmds <- list.files(path = collection_dir,
                         pattern = "^[^_].*\\.[Rr][Mm][Dd]$",
                         full.names = FALSE)

  if (length(all_rmds) == 1) {

    # just one R Markdown document
    collection_rmd <- all_rmds

  } else {

    # more than one: look for an index
    index <- which(tolower(all_rmds) == "index.rmd")
    if (length(index) > 0) {
      collection_rmd <- all_rmds[index[1]]
    }

    # look for first one that has radix_article as a default format
    else {
      for (rmd in all_rmds) {
        format <- rmarkdown::default_output_format(file.path(collection_dir, rmd), encoding)
        if (format$name == "radix::radix_article") {
          collection_rmd <- rmd
          break
        }
      }
    }
  }

  file.path(collection_dir, collection_rmd)

}


site_collections <- function(site_dir, site_config) {

  # base collections
  collections <- site_config[["collections"]]
  if (is.list(collections))
    collections <- names(collections)

  # combine with built-in collections
  collections <- unique(c("_posts", "_articles", collections))

  # filter on directory existence
  collections[dir_exists(file.path(site_dir, collections))]
}

collection_file_offset <- function(file) {
  offset_dirs <- length(strsplit(file, "/")[[1]]) - 1
  paste(rep_len("..", offset_dirs), collapse = "/")
}




# post-processor (unused for now but here to draw from for collection publishing)
collection_post_processor <- function(metadata, input_file, output_file, clean, verbose , ...) {

  # if this is a collection then move output to the output dir
  if (!is.null(site_config[["collection"]])) {

    # determine outputs we need to move
    outputs <- c()

    # sidecar files dir (if no _cache dir)
    files_dir <- knitr_files_dir(output_file)
    cache_dir <- gsub("_files$", "_cache", files_dir)
    if (dir_exists(files_dir) & !dir_exists(cache_dir))
      outputs <- c(outputs, files_dir)

    # determine the final output directory
    input_dir <- dirname(normalize_path(input_file))
    output_dir <- file.path(site_config[["collection"]]$output_dir,
                            basename(input_dir))

    # remove and re-create the output directory
    if (dir_exists(output_dir))
      unlink(output_dir, recursive = TRUE)
    dir.create(output_dir, recursive = TRUE)

    # move the html file to the output directory
    target_output_file <- file.path(output_dir, "index.html")
    file.rename(output_file, target_output_file)

    # rename output_file so that is where the preview goes
    output_file <- normalize_path(target_output_file)

    # move other outputs
    for (output in outputs) {
      output_dest <- file.path(output_dir, basename(output))
      file.rename(output, output_dest)
    }

    # copy additional supporting resources
    resources <- metadata$resources
    if (!is.null(resources))
      c(include, exclude) %<-% list(resources$include, resources$exclude)
    else
      c(include, exclude) %<-% list(NULL, NULL)
    article_resources <- site_resources(
      site_dir = input_dir,
      include = include,
      exclude = exclude,
      encoding = encoding
    )
    file.copy(from = file.path(input_dir, article_resources),
              to = output_dir,
              recursive = TRUE,
              copy.date = TRUE)
  }

  output_file
}




