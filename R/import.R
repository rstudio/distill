


#' Import a post into a blog
#'
#' Import a distill post from an external source (e.g. GitHub repo, RPubs article, etc.).
#' Importable posts must have `distill::distill_article` as the output format in the YAML.
#'
#' @inheritParams create_post
#'
#' @param url URL for distill post to import
#' @param check_license Verify that the imported posted has a creative commons license
#' @param overwrite Overwrite existing post? (defaults to `FALSE`, use [update_post()]
#'   to update an existing post in-place).
#' @param view View the post after importing it.
#'
#' @return Returns (invisibly) a logical indicating whether the operation completed
#'  (it may not complete if, for example, the user chose not to import an article
#'  that lacked a creative commons license).
#'
#' @export
import_post <- function(url, slug = "auto",
                        date = Sys.Date(),
                        date_prefix = date,
                        check_license = TRUE,
                        overwrite = FALSE,
                        view = interactive()) {
  # import article
  import_article(
    url,
    collection = "posts",
    slug = slug,
    date = date,
    date_prefix = date_prefix,
    check_license = check_license,
    overwrite = overwrite
  )
}

#' @rdname import_post
#' @export
update_post <- function(slug, view = interactive()) {
  update_article("posts", slug, view)
}


import_article <- function(url, collection, slug = "auto",
                           date = NULL, date_prefix = FALSE,
                           check_license = TRUE,
                           overwrite = FALSE,
                           view = interactive()) {

  # determine site_dir (must call from within a site)
  site_dir <- find_site_dir(".")
  if (is.null(site_dir))
    stop("You must call import from within a Distill website")

  # more discovery
  site_config <- site_config(site_dir)
  articles_dir <- file.path(site_dir, paste0("_", collection))

  # create article temp space
  article_temp_dir <- tempfile("import-article")
  dir.create(article_temp_dir, recursive = TRUE)
  article_tmp <- file.path(article_temp_dir, "index.html")

  # progress
  cat("Importing ", url, "...", "\n", sep = "")

  # download the article index
  download_url <- download_article_index(url, article_tmp)

  # extract metadata from the file
  metadata <- extract_embedded_metadata(article_tmp)

  # license check
  if (check_license) {
    if (!check_import_license(metadata[["creative_commons"]]))
      return(invisible(FALSE))
  }

  # compute the base slug
  slug <- resolve_slug(metadata$title, slug)

  # resolve date change if necessary
  if (is.character(date))
    date <- parse_date(date)
  if (!is.null(date))
    metadata$date <- format(date, format = "%m-%d-%Y")

  # if there is still no date in metadata then assign today
  if (is.null(metadata$date))
    metadata$date <- format(Sys.Date(), format = "%m-%d-%Y")

  # add date to slug if requested
  if (isTRUE(date_prefix)) {
    slug <- paste(format(parse_date(metadata$date), format = "%Y-%m-%d"), slug,
                  sep = "-")
  }

  # compute the article directory and check whether it already exists
  article_dir <- file.path(articles_dir, slug)
  if (dir_exists(article_dir) && !overwrite) {
    stop("Import failed (the article '", slug, "' already exists)\n",
         "Pass overwrite = TRUE to replace the existing article.")
  }

  # download the article
  download_article(url, download_url, article_tmp, metadata)

  # move the article into place
  move_directory(article_temp_dir, article_dir)

  # publish to site
  collections <- site_collections(site_dir, site_config)
  output_file <- publish_collection_article_to_site(
    site_dir, site_config, getOption("encoding"),
    collections[[collection]], file.path(article_dir, "index.html"), metadata,
    strip_trailing_newline = TRUE
  )

  # view output file
  if (view)
    utils::browseURL(output_file)

  # print sucess
  cat("Imported to _", collection, "/", slug, "\n", sep = "")
  maybe_cat <- function(field, value) {
    if (!is.null(value) && nzchar(value))
      cat("  ", field, ": ", value, "\n", sep = "")
  }
  maybe_cat("Title", metadata[["title"]])
  maybe_cat("Author",
            bibtex_authors(authors_with_first_and_last_names(metadata[["author"]])))
  creative_commons <- metadata[["creative_commons"]]
  if (!is.null(creative_commons))
    maybe_cat("License", creative_commons_url(creative_commons))
  else
    maybe_cat("License", "(No license detected)")

  # success
  invisible(TRUE)

}

download_article <- function(url, download_url, article_tmp, metadata) {

  # determine target directory
  article_temp_dir <- dirname(article_tmp)

  # compute base url
  base_url <- download_url
  if (grepl("\\.html?$", download_url, ignore.case = TRUE))
    base_url <- dirname(download_url)
  base_url <- ensure_trailing_slash(base_url)

  # read the index content
  index_content <- readChar(article_tmp,
                            nchars = file.info(article_tmp)$size,
                            useBytes = TRUE)

  # update the metadata (may have a revised date)
  index_content <- fill_placeholder(index_content,
                                    "front_matter",
                                    doRenderTags(front_matter_html(metadata)))
  index_content <- fill_placeholder(index_content,
                                    "rmarkdown_metadata",
                                    doRenderTags(embedded_metadata_html(metadata)))

  # provide import source
  index_content <- fill_placeholder(index_content,
                                    "import_source",
                                    doRenderTags(import_source_html(url, article_tmp)))

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
    stop("Unable to import article (this article is a page within a Distill website ",
         "rather than a standalone article", call. = FALSE)
  }

  # progress bar
  if (requireNamespace("progress", quietly = TRUE)) {
    pb <- progress::progress_bar$new(
      format = "[:bar] :percent  eta: :eta  :file",
      total = length(manifest)
    )
  } else {
    pb <- NULL
  }

  # download the files in the manifest
  rewrites <- c()
  for (file in manifest) {

    # tick
    file_progress <- stringr::str_pad(
      stringr::str_trunc(basename(file), 25, "right"), 25, "right"
    )
    if (!is.null(pb)) {
      pb$tick(tokens = list(file = file_progress))
    }


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


update_article <- function(collection, slug, view = interactive()) {

  # determine site_dir (must call from within a site)
  site_dir <- find_site_dir(".")
  if (is.null(site_dir))
    stop("You must call update from within a Distill website")

  # if the slug is an existing directory then just it's base name
  if (dir_exists(slug))
    slug <- basename(slug)

  # more discovery
  site_config <- site_config(site_dir)
  article_path <- file.path(paste0("_", collection), slug)
  article_dir <- file.path(site_dir, article_path)
  article_html <- file.path(article_dir, "index.html")

  # find import source
  import_source <- NULL
  if (file.exists(article_html))
    import_source <- extract_import_source(article_html)
  if (is.null(import_source))
    stop("Previously imported article not found at ", article_path, call. = FALSE)

  # find date
  metadata <- extract_embedded_metadata(article_html)

  # perform import (maintaining slug and date)
  import_article(
    import_source$url,
    collection,
    slug = slug,
    date = metadata$date,
    overwrite = TRUE,
    view = view
  )
}

download_article_index <- function(url, article_tmp) {

  # check for github
  download_url <- resolve_github_url(url, article_tmp)

  # check for rpubs
  if (is.null(download_url))
    download_url <- resolve_rpubs_url(url, article_tmp)

  # if none of the above then use original url
  if (is.null(download_url))
    download_url <- url

  # perform the download
  download_file(download_url, article_tmp)

  # return the download url
  download_url
}

resolve_rpubs_url <- function(url, article_tmp) {

  # if it's an RPubs url then look for the iframe within it
  if (grepl("^https?://rpubs\\.com/.*/.*$", url)) {

    # download html
    rpubs_html <- xml2::read_html(url)

    # find iframe and get url
    iframe <- xml2::xml_find_all(rpubs_html, "//iframe[@src]")
    src <- xml2::xml_attr(iframe, "src")
    url <- paste0("https:", src)

    # download file
    download_file(url, article_tmp)

    # return url
    url

  } else {
    NULL
  }

}

resolve_github_url <- function(url, article_tmp) {

  # if it's a github repo then look for an article within it
  if (grepl("^https://github\\.com/.*/.*$", url)) {

    # pull out the owner and repo
    matches <- regmatches(url,  regexec('^https://github\\.com/(.*)/([^/]+).*$', url))
    owner <- matches[[1]][[2]]
    repo <- matches[[1]][[3]]

    # determine the default branch
    branches <- jsonlite::fromJSON(sprintf("https://api.github.com/repos/%s/%s", owner, repo))
    branch <- branches$default_branch

    # download the file list as json
    repo_files <- jsonlite::fromJSON(
      sprintf("https://api.github.com/repos/%s/%s/git/trees/%s",
              owner, repo, branch),
      simplifyVector = FALSE
    )

    # collect up html files
    html_files <- Filter(x = repo_files$tree, function(file) {
      identical(file$type, "blob") && grepl("\\.html?$", file$path)
    })

    # error if there are no html files
    if (length(html_files) == 0)
      stop("No HTML files were found in the root of the specified GitHub repo")

    # look for an article
    for (html_file in html_files) {
      # form the raw url
      url <- sprintf("https://raw.githubusercontent.com/%s/%s/%s/%s",
                     owner, repo, branch, html_file$path)

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
    stop("No HTML files with output type distill::distill_article found in GitHub repo")

  } else {
    NULL
  }
}

check_import_license <- function(article_cc) {

  # if there is no article_cc then verify import
  if (is.null(article_cc)) {
    result = readline(
      "This article does not have a creative commons license. Import anyway? [Y/n]: "
    )
    if (tolower(result) == "n")
      return(FALSE)
  }

  TRUE
}

import_source_html <- function(url, article_path) {
  source <- list(
    url = url,
    sha1 = digest::digest(file = article_path, algo = "sha1")
  )
  json_html <- embedded_json(source, "radix-import-source", file = NULL)
  placeholder_html("import_source", json_html)
}

extract_import_source <- function(file) {
  extract_embedded_json(file, "radix-import-source")
}



