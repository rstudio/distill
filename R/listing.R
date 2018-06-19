

resolve_listing <- function(input_file, site_config, metadata) {

  # determine/validate collection
  collection <- metadata$listing$collection
  if (is.null(collection))
    stop("You must specify a collection for listing pages", call. = FALSE)

  # get articles
  articles <- articles_info(dirname(input_file), collection)

  # generate listing
  generate_listing(
    input_file,
    site_config,
    collection,
    articles,
    metadata$listing
  )
}

generate_listing <- function(input_file,
                             site_config,
                             collection,
                             articles,
                             options = list()) {

  # validate that the collection exists
  site_dir <- dirname(input_file)
  as_collection_dir(site_dir, collection)

  # get the collection metadata
  collection <- site_collections(site_dir, site_config)[[as_collection_name(collection)]]

  # check for and enforce a limit on feed items (defaults to 20)
  feed_articles <- articles
  feed_items_max <- not_null(options[["feed_items_max"]], 20)
  if (is.integer(feed_items_max) && (length(articles) > feed_items_max)) {
    feed_articles <- feed_articles[1:feed_items_max]
  }

  # generate feed and write it
  feed_xml <- file_with_ext(input_file, "xml")
  feed_xml <- write_feed_xml(feed_xml, site_config, collection, feed_articles)

  # generate html
  listing_html <- article_listing_html(collection, articles, options)
  html <- html_file(listing_html)

  # return feed and listing html
  list(
    feed = feed_xml,
    html = html
  )
}


article_listing_html <- function(collection, articles, options) {

  # detect whether we are showing categories in the sidebar
  categories <- options[["categories"]]
  if (is.null(categories))
    categories <- TRUE

  # if we are displaying categories then verify that articles have categories
  categories <- categories && have_categories(articles)

  # generate html
  articles_html <- lapply(articles, function(article) {

    # preview
    preview <- resolve_preview_url(article$preview, article$path)

    if (!is.null(preview))
      preview <- img(src = preview)

    a(href = article$path, class = "post-preview",
      div(class = "metadata",
        div(class = "publishedDate", date_as_abbrev(article$date))
      ),
      div(class = "thumbnail", preview),
      div(class = "description",
        h2(article$title),
        p(article$description)
      )
    )
  })

  # do we have a sidebar
  sidebar <- categories

  # wrap in a div
  if (sidebar) {
    placeholder_html("article_listing",
      div(class = "posts-container posts-with-sidebar l-screen-inset",
        div(class = "posts-list", articles_html),
        div(class = "posts-sidebar", HTML("&nbsp;"))
      )
    )
  } else {
    placeholder_html("article_listing",
      div(class = "posts-container l-page",
        div(class = "posts-list", articles_html)
      )
    )
  }
}

have_categories <- function(articles) {
  length(Filter(function(x) { length(x[["categories"]]) > 0 }, articles)) > 0
}

articles_info <- function(site_dir, collection) {
  collection <- as_collection_name(collection)
  collection_dir <- as_collection_dir(site_dir, collection)
  articles_json <- file.path(site_dir, collection_dir, file_with_ext(collection, "json"))
  if (!file.exists(articles_json))
    stop("The collection '", collection, "' does not have an article listing.\n",
         "(try running render_site() to generate the listing)", call. = FALSE)
  jsonlite::read_json(articles_json)
}

as_collection_dir <- function(site_dir, collection) {
  collection <- as_collection_name(collection)
  collection_dir <- paste0("_", collection)
  if (!dir_exists(file.path(site_dir, collection_dir)))
    stop("The collection '", collection, "' does not exist", call. = FALSE)
  collection_dir
}

as_collection_name <- function(collection) {
  if (is.list(collection))
    collection$name
  else
    collection
}

resolve_preview_url <- function(preview, path, base_url = NULL) {
  if (!is.null(preview) && !is_url(preview)) {
    if (!is.null(base_url))
      preview <- url_path(base_url, path, preview)
    else
      preview <- url_path(path, preview)
  }
  preview
}

