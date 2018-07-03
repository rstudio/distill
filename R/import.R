


#' Import a post into a blog
#'
#' Import a post from an external source (e.g. GitHub repo, RPubs article, etc.).
#'
#' @inheritParams create_post
#'
#' @param url URL for post to import
#'
#' @export
import_post <- function(url, slug = "auto",
                        date = Sys.Date(), date_prefix = TRUE,
                        overwrite = FALSE,
                        view = interactive()) {
  # import article
  import_article(
    url,
    collection = "posts",
    slug = slug,
    date = date,
    date_prefix = date_prefix,
    overwrite = overwrite
  )
}



import_article <- function(url, collection, slug = "auto",
                           date = NULL, date_prefix = FALSE,
                           overwrite = FALSE,
                           view = interactive()) {

  # determine site_dir (must call from within a site)
  site_dir <- find_site_dir(".")
  if (is.null(site_dir))
    stop("You must call import from within a Radix website")

  # more discovery
  site_config <- site_config(site_dir)
  articles_dir <- file.path(site_dir, paste0("_", collection))

  # create article temp space
  article_temp_dir <- tempfile("import-article")
  dir.create(article_temp_dir, recursive = TRUE)
  article_tmp <- file.path(article_temp_dir, "index.html")

  # progress
  message("Importing ", url, "...")

  # resolve github url if necessary
  github_url <- resolve_github_url(url, article_tmp)

  # if it's from github then record download url, otherwise download original url
  if (!is.null(github_url)) {
    url <- github_url
  } else {
    download_file(url, destfile = article_tmp)
  }

  # extract metadata from the file
  metadata <- extract_embedded_metadata(article_tmp)

  # compute the base slug
  slug <- resolve_slug(metadata$title, slug)

  # resolve date change if necessary
  if (is.character(date))
    date <- parse_date(date)
  if (!is.null(date))
    metadata$date <- as.character(date, format = "%m-%d-%Y")

  # add date to slug if requested
  if (isTRUE(date_prefix)) {
    slug <- paste(as.character(parse_date(metadata$date), format = "%Y-%m-%d"), slug,
                  sep = "-")
  }

  # compute the article directory and check whether it already exists
  article_dir <- file.path(articles_dir, slug)
  if (dir_exists(article_dir) && !overwrite) {
    stop("Import failed (the article '", slug, "' already exists)\n",
         "Pass overwrite = TRUE to replace the existing article.")
  }

  # download the article
  download_article(url, article_tmp, metadata)

  # move the article into place
  move_directory(article_temp_dir, article_dir)

  # publish to site
  collections <- site_collections(site_dir, site_config)
  output_file <- publish_collection_article_to_site(
    site_dir, site_config, getOption("encoding"),
    collections[[collection]], file.path(article_dir, "index.html"), metadata
  )

  # view output file
  if (view)
    utils::browseURL(output_file)

  # TODO: provide date by default in new radix article/post

  # TODO: license checking
  # TODO: attribution metadata?
  # TODO: updates? could just be an import where we preserve the date


  # return nothing
  invisible(NULL)

}

download_article <- function(url, article_tmp, metadata) {

  # determine target directory
  article_temp_dir <- dirname(article_tmp)

  # compute base url
  base_url <- url
  if (grepl("\\.html?$", url, ignore.case = TRUE))
    base_url <- dirname(url)
  base_url <- ensure_trailing_slash(base_url)

  # read the index content
  index_content <- readChar(article_tmp,
                            nchars = file.info(article_tmp)$size,
                            useBytes = TRUE)

  # update the metadata (may have a revised date)
  index_content <- fill_placeholder(index_content,
                                    "front_matter",
                                    as.character(front_matter_html(metadata)))
  index_content <- fill_placeholder(index_content,
                                    "rmarkdown_metadata",
                                    as.character(embedded_metadata_html(metadata)))

  # get site_libs references
  pattern <- '"[\\./]+site_libs/([^"]+)"'
  match <- gregexpr(pattern, index_content, useBytes = TRUE)
  site_libs <- gsub('"', '', regmatches(index_content, match)[[1]])
  site_libs <- unique(lapply(strsplit(site_libs, split = "site_libs/", fixed = TRUE),
                             function(lib) {
                               name = strsplit(lib[[2]], split = "/")[[1]][[1]]
                               list(
                                 name = name,
                                 url = url_path(lib[[1]], "site_libs", name)
                               )
                             }
  ))

  # extract the manifest
  manifest <- extract_manifest(article_tmp)

  # if manifest is NULL then this is a website page
  if (is.null(manifest)) {
    stop("Unable to import article (this article is a page within a Radix website ",
         "rather than a standalone article", call. = FALSE)
  }

  # progress bar
  pb <- progress::progress_bar$new(
    format = "[:bar] :percent  eta: :eta  :file",
    total = length(manifest)
  )

  # download the files in the manifest
  rewrites <- c()
  for (file in manifest) {

    # tick
    file_progress <- str_pad(str_trunc(basename(file), 25, "right"), 25, "right")
    pb$tick(tokens = list(file = file_progress))

    # ensure the destination directory exists
    destination <- file.path(article_temp_dir, file)
    destination_dir <- dirname(destination)
    if (!dir_exists(destination_dir))
      dir.create(destination_dir, recursive = TRUE)

    # the file might be found in site_libs, in that case download from site_libs/
    download_url <- url_path(base_url, file)
    for (site_lib in site_libs) {

      # if it's in site_libs then modify the download_url
      lib_pattern <- sprintf("_files/%s/", site_lib$name)
      if (grepl(lib_pattern, file, fixed = TRUE)) {
        download_url <- url_path(base_url,
                                 site_lib$url,
                                 strsplit(file, lib_pattern, fixed = TRUE)[[1]][[2]])

        # add it to list of site_libs to be re-written
        rewrite <- list(
          site_lib = site_lib$url,
          local_lib = paste0(
            strsplit(file, lib_pattern, fixed = TRUE)[[1]][[1]],
            "_files/",
            site_lib$name
          )
        )
        rewrites[[length(rewrites) + 1]] <- rewrite
      }
    }

    # perform the download
    download_file(download_url, destination)
  }

  # perform re-writes
  rewrites <- unique(rewrites)
  for (rewrite in rewrites) {
    index_content <- gsub(
      pattern = paste0('="', rewrite$site_lib),
      replacement = paste0('="', rewrite$local_lib),
      x = index_content,
      fixed = TRUE,
      useBytes = TRUE
    )
  }

  # write the index file
  writeLines(index_content, file.path(article_temp_dir, "index.html"), useBytes = TRUE)
}


resolve_github_url <- function(url, article_tmp) {

  # if it's a github repo then look for an article within it
  if (grepl("^https://github\\.com/.*/.*$", url)) {

    # pull out the owner and repo
    matches <- regmatches(url,  regexec('^https://github\\.com/(.*)/([^/]+).*$', url))
    owner <- matches[[1]][[2]]
    repo <- matches[[1]][[3]]

    # download the file list as json
    repo_files <- jsonlite::fromJSON(
      sprintf("https://api.github.com/repos/%s/%s/git/trees/master",
              owner, repo),
      simplifyVector = FALSE
    )

    # collect up html files
    html_files <- Filter(x = repo_files$tree, function(file) {
      identical(file$type, "blob") && grepl("\\.html?$", file$path)
    })

    # error if there are no html files
    if (length(html_files) == 0)
      stop("No HTML files were found in the root of the specified GitHub repo")

    # look for a radix article
    for (html_file in html_files) {
      # form the raw url
      url <- sprintf("https://raw.githubusercontent.com/%s/%s/master/%s",
                     owner, repo, html_file$path)

      # download to a temp file
      article_download <- tempfile("import-article", fileext = "html")
      download_file(url, destfile = article_download)

      # see if there is article_metadata
      article_metadata <- extract_embedded_metadata(article_download)
      if (!is.null(article_metadata)) {
        file.copy(article_download, article_tmp)
        return(url)
      }
    }

    # if we got this far without finding an article there is no article
    stop("No HTML files with output type radix::radix_article found in GitHub repo")

  } else {
    NULL
  }
}
