


manifest_in_header <- function(site_config, input_file, metadata, self_contained) {

  if (is_standalone_article(site_config) && !self_contained) {

    # get optional lists of includes/excludes
    resources <- metadata$resources
    if (!is.null(resources))
      c(include, exclude) %<-% list(resources$include, resources$exclude)
    else
      c(include, exclude) %<-% list(NULL, NULL)

    # enumerate resources
    resources <- site_resources(
      site_dir = dirname(input_file),
      include = include,
      exclude = exclude,
      recursive = TRUE
    )

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
