


#' Import a post into a blog
#'
#' Import a post from an external source (e.g. GitHub repo, RPubs article, etc.).
#'
#' @inheritParams create_post
#'
#' @param url URL for post to import
#'
#' @export
import_post <- function(url, slug = "auto", date_prefix = TRUE,
                        overwrite = FALSE) {
  import_article(
    url,
    collection = "posts",
    slug = slug,
    date_prefix = date_prefix,
    overwrite = overwrite
  )
}



import_article <- function(url, collection, slug = "auto", date_prefix = FALSE,
                           overwrite = FALSE) {

  # determine site_dir (must call from within a site)
  site_dir <- find_site_dir(".")
  if (is.null(site_dir))
    stop("You must call import from within a Radix website")

  # more discovery
  site_config <- site_config(site_dir)
  articles_dir <- file.path(site_dir, paste0("_", collection))

  # create an article temp dir
  article_temp_dir <- tempfile("import-article")
  dir.create(article_temp_dir, recursive = TRUE)

  # download the article to a temp file
  article_tmp <- file.path(article_temp_dir, "index.html")
  downloader::download(url, destfile = article_tmp, mode = "wb")

  # extract metadata from the file
  metadata <- extract_embedded_metadata(article_tmp)

  # compute the base slug
  slug <- resolve_slug(metadata$title, slug)

  # see if we need to add a date prefix
  if (!identical(date_prefix, FALSE)) {

    # determine the date
    if (is_date(date_prefix))
      date <- date_prefix
    else if (is.character(date_prefix))
      date <- parse_date(date_prefix)
    else if (isTRUE(date_prefix)) {
      if (!is.null(metadata$date))
        date <- parse_date(metadata$date)
      else
        date <- Sys.Date()
    } else {
      stop("You must specify either TRUE/FALSE or a date for date_prefix")
    }

    # modify the slug
    slug <- paste(as.character(date, format = "%Y-%m-%d"), slug, sep = "-")
  }

  # compute the article directory and check whether it already exists
  article_dir <- file.path(articles_dir, slug)
  if (dir_exists(article_dir) && !overwrite) {
    stop("Import failed (the article '", slug, "' already exists)\n",
         "Pass overwrite = TRUE to replace the existing article.")
  }

  # compute the base url path for downloads
  base_url <- url
  if (grepl("\\.html?$", url, ignore.case = TRUE))
    base_url <- dirname(url)
  base_url <- ensure_trailing_slash(base_url)

  # get site_libs references
  index_content <- readChar(article_tmp,
                            nchars = file.info(article_tmp)$size,
                            useBytes = TRUE)
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

  # download the files in the manifest
  rewrites <- c()
  for (file in manifest) {

    # ensure the destination directory exists
    destination <- file.path(article_temp_dir, file)
    destination_dir <- dirname(destination)
    if (!dir_exists(destination_dir))
      dir.create(destination_dir, recursive = TRUE)

    # the file might be found in site_libs, in that case download from site_libs/
    download_url <- url_path(url, file)
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
    downloader::download(download_url, destination)
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

  # remove the existing article_dir if necessary
  if (dir_exists(article_dir))
    unlink(article_dir, recursive = TRUE)

  # attempt to move the article in one shot (if that fails then copy it)
  result <- tryCatch(file.rename(article_temp_dir, article_dir),
                     error = function(e) FALSE)
  if (!result) {
    dir.create(article_dir, recursive = TRUE)
    file.copy(
      from = article_temp_dir,
      to = articles_dir,
      recursive = TRUE
    )
    file.rename(file.path(articles_dir, basename(article_temp_dir)), article_dir)
  }

  # TODO: Refactor of import_article code
  # TODO: Imported article should use today for date ordering

  # TODO: tolerate no manifest for self_contained
  # TODO: error on website page w/o manifest

  # TODO: render just the imported article automatically
  # TODO: preview after render (may need to be filesystem based)

  # TODO: license checking
  # TODO: attribution metadata?
  # TODO: updates?


  # return nothing
  invisible(NULL)

}
