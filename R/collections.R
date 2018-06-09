



enumerate_collections <- function(site_dir,
                                  config,
                                  site_collections,
                                  encoding = getOption("encoding")) {

  # list of collections to return
  collections <- list()

  # iterate over collections
  for (collection in names(site_collections)) {

    # collection_dir
    collection_dir <- file.path(site_dir, paste0("_", collection))

    # build a list of articles in the collection
    articles <- list()

    # find all html files within the collection
    html_files <- file.path(list.files(
                              collection_dir,
                              pattern = "^[^_].*\\.html$",
                              recursive = TRUE,
                              full.names = TRUE
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

      # transform metadata
      article$metadata <- transform_metadata(
        article$path,
        config,
        site_collections[[collection]],
        article$metadata,
        auto_preview = TRUE
      )

      # add to list of articles
      articles[[length(articles) + 1]] <- article
    }

    # sort the articles in reverse-chronological order
    indexes <- order(sapply(articles, function(x) x$metadata$date), decreasing = TRUE)
    articles <- articles[indexes]

    # add collection
    collections[[collection]] <- list(
      name = collection,
      config = site_collections[[collection]],
      articles = articles
    )
  }

  collections
}

render_collections <- function(site_dir, site_config, collections, quiet = FALSE) {

  # caching html generator
  navigation_html <- navigation_html_generator()

  # site includes
  site_includes <- site_includes(site_dir, site_config)

  # render all collections
  lapply(collections, function(collection) {
    render_collection(
      site_dir = site_dir,
      site_config = site_config,
      collection = collection,
      navigation_html = navigation_html,
      site_includes = site_includes,
      quiet = quiet
    )
  })

}


render_collection <- function(site_dir, site_config, collection,
                              navigation_html = navigation_html_generator(),
                              site_includes = site_includes(site_dir, site_config),
                              quiet = FALSE) {

  if (!quiet)
    cat(paste0("\nProcessing ", collection$name, ":\n"))

  # remove existing output dir if it exists
  collection_output <- file.path(site_dir,
                                 site_config$output_dir,
                                 collection$name)
  if (dir_exists(collection_output))
    unlink(collection_output, recursive = TRUE)

  # process articles in collection
  lapply(collection$articles, function(article) {
    render_collection_article(
      site_dir = site_dir,
      site_config = site_config,
      article = article,
      navigation_html = navigation_html,
      site_includes = site_includes,
      quiet = quiet
    )
  })

  if (!quiet)
    cat("\n")
}


render_collection_article_post_processor <- function(encoding_fn) {

  function(metadata, input_file, output_file, clean, verbose) {

    # resolve encoding
    encoding <- encoding_fn()

    # is the input file at the top level of a site? if it is then no post processing
    site_config <- site_config(input_file, encoding)
    if (!is.null(site_config))
      return(output_file)

    # is the input file in a site? if not then no post processing
    site_dir <- find_site_dir(input_file)
    if (is.null(site_dir))
      return(output_file)

    # get the site config
    site_config <- site_config(site_dir, encoding)

    # is this file in a collection? if not then no post processing
    collections <- site_collections(site_dir, site_config)
    input_file_relative <- rmarkdown::relative_to(
      normalize_path(site_dir),
      normalize_path(input_file)
    )
    in_collection <- startsWith(input_file_relative, paste0("_", names(collections), "/"))
    if (!any(in_collection))
      return(ouput_file)

    # get the collection
    collection <- collections[[which(in_collection)]]

    # compute the article path
    article_path <- file.path(site_dir, dirname(input_file_relative), output_file)

    # transform metadata for site
    metadata <- transform_metadata(
      article_path,
      site_config,
      collection,
      metadata,
      auto_preview = TRUE
    )

    # form an article object
    article <- list(
      path = article_path,
      metadata = metadata
    )

    # render the article
    output_file <- render_collection_article(
      site_dir = site_dir,
      site_config = site_config,
      article = article,
      navigation_html = navigation_html_generator(),
      site_includes = site_includes(site_dir, site_config),
      quiet = TRUE
    )

    # TODO: one line difference btw incremental and site render
    # TODO: rstudio ide change + throttle preview on that
    # TODO: write index as json and have index page read the json
    # TODO: update feed
    # TODO: drafts: don't post-process for draft and remove from _site for draft


    # return the output_file w/ an attribute indicating that
    # base post processing should be done on both the new
    # and original output file
    structure(output_file, post_process_original = TRUE)
  }
}


render_collection_article <- function(site_dir, site_config, article,
                                      navigation_html, site_includes,
                                      quiet = FALSE) {

  # strip site_dir prefix
  article_site_path <- sub(paste0("^", site_dir, "/"), "", article$path)

  # compute offset
  offset <- collection_file_offset(article_site_path)

  # determine the target output dir
  output_dir <- file.path(site_dir,
                          site_config$output_dir,
                          sub("^_", "", dirname(article_site_path)))

  # progress
  if (!quiet)
    cat(" ", dirname(article_site_path), "\n")

  # create the output directory
  if (!dir_exists(output_dir))
    dir.create(output_dir, recursive = TRUE)

  # copy files to output directory
  resources <- article$metadata$resources
  if (!is.null(resources))
    c(include, exclude) %<-% list(resources$include, resources$exclude)
  else
    c(include, exclude) %<-% list(NULL, NULL)
  rmd_resources <- site_resources(
    site_dir = dirname(article$path),
    include = include,
    exclude = exclude
  )
  file.copy(from = file.path(dirname(article$path), rmd_resources),
            to = output_dir,
            recursive = TRUE,
            copy.date = TRUE)

  # rename article to index.html
  article_html <- file.path(output_dir, basename(article_site_path))
  index_html <- file.path(output_dir, "index.html")
  if (article_html != index_html)
    file.rename(article_html, index_html)

  # transform site_config and get metadata from article
  site_config <- transform_site_config(site_config)
  metadata <- article$metadata

  # read index content
  index_content <- readChar(index_html,
                            nchars = file.info(index_html)$size,
                            useBytes = TRUE)

  # substitute metadata
  metadata_html <- metadata_html(site_config, metadata, self_contained = FALSE)
  index_content <- fill_placeholder(index_content,
                                    "meta_tags",
                                    as.character(metadata_html))

  # substitue appendices
  appendices_html <- appendices_after_body_html(site_config, metadata)
  index_content <- fill_placeholder(index_content,
                                    "appendices",
                                    as.character(appendices_html))

  # substitute navigation html
  navigation <- navigation_html(site_dir, site_config, offset)
  apply_navigation <- function(content, context) {
    fill_placeholder(content, paste0("navigation_", context), navigation[[context]])
  }
  index_content <- apply_navigation(index_content, "in_header")
  index_content <- apply_navigation(index_content, "before_body")
  index_content <- apply_navigation(index_content, "after_body")

  # substitute site includes
  apply_site_include <- function(content, context) {
    fill_placeholder(content, paste0("site_", context), site_includes[[context]])
  }
  index_content <- apply_site_include(index_content, "in_header")
  index_content <- apply_site_include(index_content, "before_body")
  index_content <- apply_site_include(index_content, "after_body")

  # resolve site_libs
  site_libs <- file.path(site_dir, site_config$output_dir, "site_libs")
  index_content <- apply_site_libs(index_content, article_html, site_libs, offset)

  # write content
  writeLines(index_content, index_html, useBytes = TRUE)

  # return path to rendered article
  index_html
}

apply_site_libs <- function(index_content, article_path, site_libs, offset) {

  # find _files directories referenced from script and link tags
  files_dir <- knitr_files_dir(basename(article_path))
  pattern <- sprintf('((?:<script src=|<link href=)")(%s)(/[^/]+/)', files_dir)
  match <- gregexpr(pattern, index_content, useBytes = TRUE)
  dirs <- sapply(strsplit(regmatches(index_content, match)[[1]], split = "/"), `[[`, 2)
  dirs <- unique(dirs)

  # move the directories to site_libs as necessary
  for (dir in dirs) {
    article_lib_dir <- file.path(dirname(article_path), files_dir, dir)
    site_lib_dir <- file.path(site_libs, dir)
    if (!dir_exists(site_lib_dir))
      file.rename(article_lib_dir, site_lib_dir)
    else
      unlink(article_lib_dir, recursive = TRUE)
  }

  # fixup html
  gsub(pattern,
       sprintf("\\1%s/%s\\3", offset, basename(site_libs)),
       index_content,
       useBytes = TRUE)
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
        metadata = article_metadata
      )
    } else {
      NULL
    }
  } else {
    NULL
  }
}



write_collections_metadata <- function(site_dir, collections) {
  for (collection in collections)
    write_collection_metadata(site_dir, collection)
}

write_collection_metadata <- function(site_dir, collection) {

  # articles yaml
  collection_yaml <- collection_yaml_path(site_dir, collection)
  con <- file(collection_yaml, "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  # header
  cat("# Created by Radix website generator (do not edit or remove)\n", file = con)

  # write each article
  articles <- lapply(collection[["articles"]], function(article) {

    # strip some inside-baseball metadata
    article$metadata$output <- NULL
    article$metadata$resources <- NULL

    # write the article
    article_yaml <- append(list(path = basename(dirname(article$path))),
                                article$metadata)
    cat("\n", file = con)
    yaml::write_yaml(list(article_yaml), file = con)
  })
}

remove_collections_metadata <- function(site_dir, collections) {
  for (collection in collections)
    remove_collection_metadata(site_dir, collection)
}

remove_collection_metadata <- function(site_dir, collection) {
  file.remove(collection_yaml_path(site_dir, collection))
}

collection_yaml_path <- function(site_dir, collection) {
  name <- collection[["name"]]
  file.path(
    site_dir,
    paste0("_", name),
    file_with_ext(name, ext = "yml")
  )
}


site_collections <- function(site_dir, site_config) {

  # collections defined in file
  collections <- site_config[["collections"]]
  if (is.null(collections))
    collections <- list()
  else if (is.character(collections)) {
    collection_names <- names(collections)
    collections <- lapply(collections, function(collection) {
      list()
    })
    names(collections) <- collection_names
  }
  else if (is.list(collections)) {
    if (is.null(names(collections)))
      stop('Site collections must be specified as a named list', call. = FALSE)
  }

  # automatically include posts and articles
  ensure_collection <- function(name) {
    if (!name %in% names(collections))
      collections[[name]] <<- list()
  }
  ensure_collection("posts")
  ensure_collection("articles")

  # filter on directory existence
  collections <- collections[file.exists(file.path(site_dir, paste0("_", names(collections))))]

  # add name field
  for (name in names(collections))
    collections[[name]][["name"]] <- name

  # inherit some properties from the site
  lapply(collections, function(collection) {
    inherit_prop <- function(name) {
      if (is.null(collection[[name]]))
        collection[[name]] <<- site_config[[name]]
    }
    inherit_prop("title")
    inherit_prop("description")
    inherit_prop("copyright")
    collection
  })

}


collection_file_offset <- function(file) {
  offset_dirs <- length(strsplit(file, "/")[[1]]) - 1
  paste(rep_len("..", offset_dirs), collapse = "/")
}



