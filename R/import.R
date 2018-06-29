


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

  # download the article to a temp file
  article_tmp <- tempfile("import-article", fileext = ".html")
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
  if (dir_exists(article_dir)) {
    if (overwrite)
      unlink(article_dir, recursive = TRUE)
    else
      stop("Import failed (the article '", slug, "' already exists)\n",
           "Pass overwrite = TRUE to replace the existing article.")
  }

  # create the article dir
  dir.create(article_dir, recursive = TRUE)

  # save the article into it
  file.copy(
    article_tmp,
    file.path(article_dir, "index.html")
  )

  # TODO: download resource files via manifest
  # TODO: fixup ../../site_dir after download
  # TODO render just the imported article automatically

  # TODO: license checking
  # TODO: attribution metadata?
  # TODO: updates?


  # return nothing
  invisible(NULL)
}
