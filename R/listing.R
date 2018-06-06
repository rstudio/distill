

listing_before_body <- function(metadata) {

  if(!is.null(metadata$listing)) {

    # determine/validate collection
    collection <- metadata$listing$collection
    if (is.null(collection))
      stop("You must specify a collection for listing pages", call. = FALSE)

    # generate html
    articles <- article_listing(collection)
    listing_html <- article_listing_html(collection, articles)

    # return as file
    html_file(listing_html)


  } else {
    NULL
  }
}


article_listing_html <- function(collection, articles) {

  # generate html
  articles_html <- lapply(articles, function(article) {

    path <- file.path(collection, article$path)

    metadata <- div(class = "metadata",
      div(class = "publishedDate",
          sprintf("%s %d, %s",
          article$published_month,
          article$published_day,
          article$published_year))
    )

    # make the preview_url relative if possible
    preview <- article$preview_url
    if (is.null(preview) || startsWith(preview, article$base_url)) {
      if (!is.null(article$preview))
        preview <- file.path(path, article$preview)
    }
    if (!is.null(preview))
      preview <- img(src = preview)
    thumbnail <- div(class = "thumbnail",
      preview
    )

    description <- div(class = "description",
      h2(article$title),
      p(article$description)
    )

    a(href = paste0(path, "/"), class = "post-preview",
      metadata,
      thumbnail,
      description
    )
  })

  # wrap in a div
  div(class = "posts-list l-page", articles_html)
}


article_listing_xml <- function(collection, articles = article_listing(collection)) {

  # create document root
  rss <- xml2::xml_new_root("rss",
    version = "2.0",
    "xmlns:atom" = "http://www.w3.org/2005/Atom",
    "xmlns:media" = "http://search.yahoo.com/mrss/"
  )

  # helper to add a child element
  add_child <- function(node, tag, attribs = c(), text = NULL) {
    child <- xml2::xml_add_child(node, tag)
    xml2::xml_set_attrs(child, attribs)
    if (!is.null(text))
      xml2::xml_text(child) <- text
    child
  }

  # create channel
  channel <- xml2::xml_add_child(rss, "channel")
  add_child(channel, "title", text = "My Title")

  item <- add_child(channel, "item")


  # return xml document
  rss

}

article_listing <- function(collection) {
  collection_dir <- as_collection_dir(collection)
  articles_yaml <- file.path(collection_dir, file_with_ext(collection, "yml"))
  if (!file.exists(articles_yaml))
    stop("The collection '", collection, "' does not have an article listing.\n",
         "(try running render_site() to generate the listing)", call. = FALSE)
  yaml::yaml.load_file(articles_yaml)
}

as_collection_dir <- function(collection) {
  collection_dir <- paste0("_", collection)
  if (!dir_exists(collection_dir))
    stop("The collection '", collection, "' does not exist", call. = FALSE)
  collection_dir
}


