


manifest_in_header <- function(site_config, input_file, metadata, self_contained) {

  if (is_standalone_article(site_config)) {

    if (!self_contained) {
      # get optional lists of includes/excludes
      resources <- metadata$resources
      if (!is.null(resources)) {
        include <- resources$include
        exclude <- resources$exclude
      } else {
        include <- NULL
        exclude <- NULL
      }

      # add base html file to exclude (as it will be renamed to index.html)
      exclude <- c(exclude, file_with_ext(input_file, "html"))

      # enumerate resources
      resources <- site_resources(
        site_dir = dirname(input_file),
        include = include,
        exclude = exclude,
        recursive = TRUE
      )
    } else {
      resources <- list()
    }

    # serialize as json
    embedded_json(resources, "radix-resource-manifest")
  } else {
    c()
  }
}


extract_manifest <- function(input_file) {
  extract_embedded_json(input_file, "radix-resource-manifest")
}

is_standalone_article <- function(site_config) {
  length(site_config) == 0
}
