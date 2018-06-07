

resolve_listing <- function(input_file, site_config, metadata) {
  # determine/validate collection
  collection <- metadata$listing$collection
  if (is.null(collection))
    stop("You must specify a collection for listing pages", call. = FALSE)

  # validate that the collection exists
  site_dir <- dirname(input_file)
  as_collection_dir(site_dir, collection)

  # get the collection and article metadata
  collection <- site_collections(site_dir, site_config)[[collection]]
  articles <- article_listing(site_dir, collection)

  # generate feed and write it
  feed_xml <- file_with_ext(input_file, "xml")
  feed_xml <- write_feed_xml(feed_xml, site_config, collection, articles)

  # generate html
  articles <- article_listing(input_as_dir(input_file), collection)
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

    path <- file.path(collection$name, article$path)

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
  add_child(channel, "lastBuildDate", text = date_as_rfc_2822(Sys.time()))
  add_child(channel, "ttl", text = not_null(collection$ttl, "60"))

  # add entries to channel
  for (article in articles) {
    # core fields
    item <- add_child(channel, "item")
    add_child(item, "title", text = article$title)
    add_child(item, "link", attr = c(href = article$base_url))
    add_child(item, "description", text = not_null(article$description, default = article$title))
    add_child(item, "guid", text = article$base_url)
    add_child(item, "pubDate", text = date_as_rfc_2822(article$published_date_rfc))

    # preview image
    if (!is.null(article$preview_url)) {
      preview <- add_child(item, "media:content", attr = c(
        url = article$preview_url,
        medium = "image",
        type = mime::guess_type(article$preview_url)
      ))
      if (!is.null(article$preview_width)) {
        xml2::xml_set_attr(preview, "width", article$preview_width)
        xml2::xml_set_attr(preview, "height", article$preview_height)
      }
    }
  }

  # write the feed file
  xml2::write_xml(feed, feed_xml)

  # track the output (for moving to the _site directory later)
  add_site_output(feed_xml)

}


article_listing <- function(site_dir, collection) {
  collection <- collection$name
  collection_dir <- as_collection_dir(site_dir, collection)
  articles_yaml <- file.path(site_dir, collection_dir, file_with_ext(collection, "yml"))
  if (!file.exists(articles_yaml))
    stop("The collection '", collection, "' does not have an article listing.\n",
         "(try running render_site() to generate the listing)", call. = FALSE)
  yaml::yaml.load_file(articles_yaml)
}

as_collection_dir <- function(site_dir, collection) {
  collection_dir <- paste0("_", collection)
  if (!dir_exists(file.path(site_dir, collection_dir)))
    stop("The collection '", collection, "' does not exist", call. = FALSE)
  collection_dir
}


