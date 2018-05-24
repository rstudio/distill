

render_collections <- function(site_dir, encoding = getOption("encoding")) {

  # build shared navigational html


  # render collections
  collections <- file.path(site_dir, c("_posts", "_articles"))
  lapply(collections[dir_exists(collections)], function(collection) {
    render_collection(collection, site_dir, encoding)
  })
}

render_collection <- function(collection, site_dir = ".", encoding = getOption("encoding")) {

  # get collection src_dir
  collection_src_dir <- file.path(site_dir, paste0("_", collection))





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

