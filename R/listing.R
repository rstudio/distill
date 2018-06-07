

resolve_listing <- function(input_file, site_config, metadata) {

  if(!is.null(metadata$listing)) {

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
    write_feed_feed(input_file, site_config, collection, articles)

    # generate html and return it
    articles <- article_listing(input_as_dir(input_file), collection)
    listing_html <- article_listing_html(collection, articles)
    html_file(listing_html)


  } else {
    NULL
  }
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

write_feed_feed <- function(input_file, site_config, collection, articles) {

  # we can't write an feed feed if there is no base_url
  if (is.null(site_config$base_url)) {
    rendering_note("Not creating feed for", collection$name,
                   "(no base_url defined for site)")
    return()
  }

  # create document root
  feed <- xml2::xml_new_root("feed",
    version = "2.0",
    "xmlns:atom" = "http://www.w3.org/2005/Atom",
    "xmlns:media" = "http://search.yahoo.com/mrss/"
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
  add_channel_attribute("description")



  # add entries to channel
  for (article in articles) {

    entry <- add_child(channel, "entry")
    add_child(entry, "title", text = article$title)
    add_child(entry, "summary", text = article$description)
    add_child(entry, "link", attr = c(href = article$base_url))
    add_child(entry, "id", text = article$base_url)
  }



  # write the feed file
  feed_path <- file.path(dirname(input_file), file_with_ext(input_file, "xml"))
  xml2::write_xml(feed, feed_path)

  # track the output (for moving to the _site directory later)
  add_site_output(feed_path)

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


