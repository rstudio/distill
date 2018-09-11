

resolve_listing <- function(input_file, site_config, metadata) {

  # alias collection
  collection <- metadata$listing

  # get articles
  articles <- articles_info(dirname(input_file), collection)

  # generate listing
  generate_listing(
    input_file,
    site_config,
    collection,
    articles
  )
}

resolve_yaml_listing <- function(input_file, site_config, metadata, yaml_listing) {

  yaml_listing <- yaml::yaml.load(yaml_listing[[1]]$code)

  listing_articles <- list()

  for (collection in names(yaml_listing)) {

    articles <- yaml_listing[[collection]]

    all_articles <- read_json(
      file.path(dirname(input_file),
                site_config$output_dir,
                collection,
                file_with_ext(collection, "json"))
    )

    articles <- lapply(articles, function(article) {
      path <- paste0(collection, "/", article, "/")
      for (article in all_articles) {
        if (identical(path, article$path))
          return(article)
      }
      NULL
    })
    articles[sapply(articles, is.null)] <- NULL

    listing_articles <- append(listing_articles, articles)
  }

  # generate html
  listing_html <- html_for_articles(listing_articles, caption = metadata$title, categories = TRUE)

  listing <- list(
    html = html_file(listing_html)
  )
}

generate_listing <- function(input_file,
                             site_config,
                             collection,
                             articles) {

  # validate that the collection exists
  site_dir <- dirname(input_file)
  as_collection_dir(site_dir, collection)

  # get the collection metadata
  collection <- site_collections(site_dir, site_config)[[as_collection_name(collection)]]

  # check for and enforce a limit on feed items (defaults to 20)
  feed_articles <- articles
  feed_items_max <- not_null(collection[["feed_items_max"]], 20)
  if (is.integer(feed_items_max) && (length(articles) > feed_items_max)) {
    feed_articles <- feed_articles[1:feed_items_max]
  }

  # generate feed and write it
  feed_xml <- file_with_ext(input_file, "xml")
  feed_xml <- write_feed_xml(feed_xml, site_config, collection, feed_articles)

  # generate html
  listing_html <- article_listing_html(site_dir, collection, articles)
  html <- html_file(listing_html)

  # return feed and listing html
  list(
    feed = feed_xml,
    html = html
  )
}


article_listing_html <- function(site_dir, collection, articles) {

  # detect whether we are showing categories in the sidebar
  categories <- not_null(collection[["categories"]], TRUE)

  # check for subscription
  subscription_html <- subscription_html(site_dir, collection)
  if (!is.null(subscription_html)) {
    subscription_html <- tags$div(class = "sidebar-section subscribe",
      tags$h3("Subscribe"),
      subscription_html
    )
  }

  # generate html
  html_for_articles(articles,
                    caption = NULL,
                    categories = categories,
                    subscription_html = subscription_html)
}

html_for_articles <- function(articles, caption = NULL, categories = FALSE, subscription_html = NULL) {

  # generate categories listing
  categories_html <- if (categories) categories_listing_html(articles)

  # generate html
  articles_html <- lapply(articles, function(article) {

    # metadata
    metadata <- list()
    metadata$categories <- as.character(article[["categories"]])

    if (!is.null(article$preview))
      preview <- img(`data-src` = article$preview)
    else
      preview <- NULL

    a(href = article$path, class = "post-preview",
      tags$script(class = "post-metadata", type = "text/json",
                  HTML(jsonlite::toJSON(metadata))),
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

  # prepend caption if we have it
  if (!is.null(caption)) {
    articles_html <- htmltools::tagList(
      h1(class = "posts-list-caption", caption),
      articles_html
    )
  }

  # more posts link
  more_posts <- div(class = "posts-more",
    tags$a(href = "#", HTML("More articles &raquo;"))
  )

  # do we have a sidebar
  sidebar <- !is.null(subscription_html) || !is.null(categories_html)

  # required JS and CSS
  listing_js_css <- html_from_file(
    system.file("rmarkdown/templates/radix_article/resources/listing.html",
                 package = "radix")
  )

  # wrap in a div
  if (sidebar) {
    placeholder_html("article_listing", tagList(
      listing_js_css,
      div(class = "posts-container posts-with-sidebar posts-apply-limit l-screen-inset",
        div(class = "posts-list", articles_html),
        div(class = "posts-sidebar", subscription_html, categories_html),
        more_posts
      )
    ))
  } else {
    placeholder_html("article_listing", tagList(
      listing_js_css,
      div(class = "posts-container posts-apply-limit l-page",
        div(class = "posts-list", subscription_html, articles_html),
        more_posts
      )
    ))
  }
}

subscription_html <- function(site_dir, collection) {

  # check for subscribe entry
  subscribe <- collection[["subscribe"]]
  if (!is.null(subscribe)) {
    subscribe <- file.path(site_dir, subscribe)
    if (!file.exists(subscribe))
      stop("Specified subscribe file '", subscribe, "' does not exist", call. = FALSE)
    html_from_file(subscribe)
  } else {
    NULL
  }

}

categories_listing_html <- function(articles) {

  # count categories
  categories <- list()
  for (article in articles) {
    for (category in article[["categories"]])
      categories[[category]] <- not_null(categories[[category]], 0) + 1
  }

  if (length(categories) > 0) {

    # sort alphabetically
    indexes <- order(names(categories))
    categories <- categories[indexes]

    # generate html
    tags$div(class = "sidebar-section categories",
      tags$h3("Categories"),
      tags$ul(
        lapply(names(categories), function(name) {
          tags$li(
            tags$a(href = paste0("#",gsub(" ", "_", name)), name),
            tags$span(class = "category-count", sprintf("(%d)", categories[[name]]))
          )
        })
      )
    )

  } else {
    NULL
  }
}



articles_info <- function(site_dir, collection) {
  collection <- as_collection_name(collection)
  collection_dir <- as_collection_dir(site_dir, collection)
  articles_json <- file.path(site_dir, collection_dir, file_with_ext(collection, "json"))
  if (!file.exists(articles_json))
    stop("The collection '", collection, "' does not have an article listing.\n",
         "(try running render_site() to generate the listing)", call. = FALSE)
  read_json(articles_json)
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

resolve_preview_url <- function(preview, path) {
  if (!is.null(preview) && !is_url(preview))
    preview <- url_path(path, preview)
  preview
}

absolute_preview_url <- function(preview_url, base_url) {
  if (!is.null(preview_url) && !is_url(preview_url))
    url_path(base_url, preview_url)
  else
    preview_url
}

