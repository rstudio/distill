

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
  listing_html <- article_listing_html(collection, articles)
  html <- html_file(listing_html)

  # return feed and listing html
  list(
    feed = feed_xml,
    html = html
  )
}


article_listing_html <- function(collection, articles) {

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

  # wrap in a div
  placeholder_html("article_listing",
    div(class = "posts-list l-page", articles_html)
  )
}


write_feed_xml <- function(feed_xml, site_config, collection, articles) {

  # we can't write an rss feed if there is no base_url
  if (is.null(site_config$base_url)) {
    rendering_note("Not creating feed for", collection$name,
                   "(no base_url defined for site)")
    return(NULL)
  }

  # we can't write an rss feed if there is no description
  if (is.null(collection$description)) {
    rendering_note("Not creating feed for", collection$name,
                   "(no description provided)")
    return(NULL)
  }

  # create document root
  feed <- xml2::xml_new_root("rss",
    "xmlns:atom" = "http://www.w3.org/2005/Atom",
    "xmlns:media" = "http://search.yahoo.com/mrss/",
    "xmlns:content" = "http://purl.org/rss/1.0/modules/content/",
    "xmlns:dc" = "http://purl.org/dc/elements/1.1/",
    version = "2.0"
  )

  # helper to add a child element
  add_child <- function(node, tag, attr = c(), text = NULL, optional = FALSE) {
    child <- xml2::xml_add_child(node, tag)
    xml2::xml_set_attrs(child, attr)
    if (!is.null(text))
      xml2::xml_text(child) <- text
    child
  }

  # create channel
  channel <- xml2::xml_add_child(feed, "channel")
  add_channel_attribute <- function(name) {
    if (!is.null(collection[[name]]))
      add_child(channel, name, text = collection[[name]])
  }
  add_channel_attribute("title")
  add_child(channel, "link", text = site_config$base_url)
  add_child(channel, "atom:link", attr = c(
    href = url_path(site_config$base_url, feed_xml),
    rel = "self",
    type = "application/rss+xml")
  )
  add_channel_attribute("description")
  if (!is.null(site_config$favicon)) {
    image <- add_child(channel, "image")
    add_child(image, "title", text = site_config$title)
    add_child(image, "url", text = url_path(site_config$base_url, site_config$favicon))
    add_child(image, "link", text = site_config$base_url)
  }
  add_channel_attribute("copyright")
  add_child(channel, "generator", text = "Radix")

  # last build date is date of most recent article (or now if no articles)
  last_build_date <- NULL
  if (length(articles) > 0)
    last_build_date <- articles[[1]]$date
  if (is.null(last_build_date))
    last_build_date <- Sys.Date()
  add_child(channel, "lastBuildDate", text = date_as_rfc_2822(last_build_date))

  # add entries to channel
  for (article in articles) {

    # calculate base url
    article$base_url <- url_path(site_config$base_url, article$path)

    # core fields
    item <- add_child(channel, "item")
    add_child(item, "title", text = article$title)
    for (author in article$author)
      add_child(item, "dc:creator", text = author$name)
    add_child(item, "link", text = article$base_url)
    add_child(item, "description", text = not_null(article$description, default = article$title))
    add_child(item, "guid", text = article$base_url)
    add_child(item, "pubDate", text = date_as_rfc_2822(article$date))

    # preview image
    preview_img <- NULL
    if (!is.null(article$preview)) {
      article$preview <- resolve_preview_url(article$preview,
                                             article$path,
                                             base_url = site_config$base_url)
      # rss tag
      media_content <- add_child(item, "media:content", attr = c(
        url = article$preview,
        medium = "image",
        type = mime::guess_type(article$preview)
      ))
      if (!is.null(article$preview_width)) {
        xml2::xml_set_attr(media_content, "width", article$preview_width)
        xml2::xml_set_attr(media_content, "height", article$preview_height)
      }

      # html tag
      preview_img <- img(src = article$preview,
                         width = knitr::opts_chunk$get("fig.width") * 96)
    }

    # content:encoded (commented out b/c most feed readers seem to more or less
    # synthesize this from description + media:content)
    # content_encoded <- add_child(item, "content:encoded")
    # xml2::xml_add_child(content_encoded, xml2::xml_cdata(as.character(tagList(
    #   p(article$description),
    #   p(preview_img)
    # ))))

  }

  # write the feed file
  xml2::write_xml(feed, feed_xml)

  # track the output (for moving to the _site directory later)
  add_site_output(feed_xml)

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

