

collection_feed_xml <- function(site_dir, collection) {

  # get articles
  articles = article_listing(site_dir, collection$name)

  # create document root
  rss <- xml2::xml_new_root("rss",
                            version = "2.0",
                            "xmlns:atom" = "http://www.w3.org/2005/Atom",
                            "xmlns:media" = "http://search.yahoo.com/mrss/"
  )

  # helper to add a child element
  add_child <- function(node, tag, attribs = c(), text = NULL, optional = FALSE) {
    child <- xml2::xml_add_child(node, tag)
    xml2::xml_set_attrs(child, attribs)
    if (!is.null(text))
      xml2::xml_text(child) <- text
    child
  }

  # create channel
  channel <- xml2::xml_add_child(rss, "channel")
  add_channel_attribute <- function(name) {
    if (!is.null(collection[[name]]))
      add_child(channel, name, text = collection[[name]])
  }
  add_channel_attribute("title")
  add_channel_attribute("description")


  item <- add_child(channel, "item")


  # return xml document
  rss

}

posts_xml <- function(site_dir = ".") {

  collection <- site_collections(site_dir, site_config(site_dir))[["posts"]]

  cat(as.character(collection_feed_xml(site_dir, collection)))

}
