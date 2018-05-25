



enumerate_collections <- function(site_dir, encoding = getOption("encoding")) {

  # read site config
  config <- site_config(site_dir, encoding)

  # list of collections to return
  collections <- list()

  for (collection in site_collections(site_dir, config)) {

    # build a list of articles in the collection
    articles <- list()

    # find all html files within the collection
    html_files <- file.path(site_dir,
                            collection,
                            list.files(
                              file.path(site_dir, collection),
                              pattern = "^[^_].*\\.html$",
                              recursive = TRUE
                            ))

    # find unique directories from files (only one article per directory)
    article_dirs <- unique(dirname(html_files))

    for (article_dir in article_dirs) {

      # resolve to radix article
      article <- discover_article(article_dir)

      # bail if there was none found
      if (is.null(article))
        next

      # bail if this is a draft
      if (isTRUE(article$metadata$draft))
        next

      # add to list of articles
      articles[[length(articles) + 1]] <- article
    }

    # add collection
    collections[[collection]] <- list(
      name = collection,
      articles = articles
    )
  }

  collections
}



render_collections <- function(site_dir, encoding = getOption("encoding"), quiet = FALSE) {

  # read site config
  config <- site_config(site_dir, encoding)

  # enumerate collections
  collections <- enumerate_collections(site_dir, encoding)

  # caching html generator
  navigation_html <- navigation_html_generator()

  for (collection in collections) {

    if (!quiet)
      cat(paste0("Rendering ", collection$name, ":\n"))

    # remove existing output dir if it exists
    collection_output <- file.path(site_dir,
                                   config$output_dir,
                                   sub("^_", "", collection$name))
    if (dir_exists(collection_output))
      unlink(collection_output, recursive = TRUE)

    # process articles in collection
    for (article in collection$articles) {

      # strip site_dir prefix
      article$path <- sub(paste0("^", site_dir, "/"), "", article$path)

      # compute offset
      offset <- collection_file_offset(article$path)

      # determine the target output dir
      output_dir <- file.path(site_dir,
                              config$output_dir,
                              sub("^_", "", dirname(article$path)))

      # progress
      if (!quiet)
        cat(" ", dirname(article$path), "\n")

      # create the output directory
      dir.create(output_dir, recursive = TRUE)

      # copy files to output directory
      resources <- article$metadata$resources
      if (!is.null(resources))
        c(include, exclude) %<-% list(resources$include, resources$exclude)
      else
        c(include, exclude) %<-% list(NULL, NULL)
      rmd_resources <- site_resources(
        site_dir = article$dir,
        include = include,
        exclude = exclude,
        encoding = encoding
      )
      file.copy(from = file.path(article$dir, rmd_resources),
                to = output_dir,
                recursive = TRUE,
                copy.date = TRUE)

      # rename article to index.html
      article_html <- file.path(output_dir, basename(article$path))
      index_html <- file.path(output_dir, "index.html")
      if (article_html != index_html)
        file.rename(article_html, index_html)

      # substitute navigation html
      navigation <- navigation_html(site_dir, config, offset)
      apply_navigation <- function(content, context) {
        fill_placeholder(content, paste0("navigation_", context), navigation[[context]])
      }
      index_content <- paste(readLines(index_html, encoding = "UTF-8"), collapse = "\n")
      index_content <- apply_navigation(index_content, "in_header")
      index_content <- apply_navigation(index_content, "before_body")
      index_content <- apply_navigation(index_content, "after_body")
      writeLines(index_content, index_html, useBytes = TRUE)
    }

    if (!quiet)
      cat("\n")
  }
}


discover_article <- function(article_dir) {

  article_html <- NULL
  article_metadata <- NULL

  html_files <- list.files(path = article_dir,
                           pattern = "^[^_].*\\.html$",
                           full.names = TRUE)

  if (length(html_files) == 1) {

    # just one html file
    article_html <- html_files[[1]]

  } else {

    # more than one: look for an index
    index <- which(tolower(basename(html_files)) == "index.html")
    if (length(index) > 0) {
      article_html <- html_files[[index[1]]]
    }

    # look for first one that has radix metadata in it
    else {
      for (html_file in html_files) {
        article_metadata <- extract_embedded_metadata(html_file)
        if (!is.null(article_metadata)) {
          article_html <- html_file
          break
        }
      }
    }
  }

  if (!is.null(article_html)) {

    # complete metadata
    if (is.null(article_metadata))
      article_metadata <- extract_embedded_metadata(article_html)

    # return if we have metadata
    if (!is.null(article_metadata)) {
      list(
        path = article_html,
        dir = article_dir,
        metadata = article_metadata
      )
    } else {
      NULL
    }
  } else {
    NULL
  }
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



