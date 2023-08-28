

write_search_json <- function(site_dir, config) {

  # path to search.json
  site_output_dir <- file.path(site_dir, config$output_dir)
  search_json <- file.path(site_output_dir, "search.json")

  # top-level articles
  input_files <- list.files(site_dir, pattern = "^[^_].*\\.[Rr]?md$")
  articles <- lapply(input_files, function(file) {

    # article w/ path
    article <- list()
    html_file <- file_with_ext(file, "html")
    article$path = as_utf8(html_file)

    # resolve path and ensure the file exists
    path <- normalize_path(file.path(site_output_dir, html_file), mustWork = FALSE)
    if (file.exists(path)) {
      contents <- article_contents(path)
      metadata <- rmarkdown::yaml_front_matter(file.path(site_dir, file))
      article <- list()
      article$path = as_utf8(html_file)
      article$title <- as_utf8(metadata$title)
      article$description <- as_utf8(metadata$description)
      article$author = lapply(metadata$author, function(author) {
        list(
          name = as_utf8(author$name),
          url = author$url
        )
      })
      article$date <- as_utf8(metadata$date)
      article$contents = as_utf8(contents)
      article$last_modified = time_as_iso_8601(file.info(path)$mtime)
    }
    article
  })

  # filter on existence
  articles <- Filter(function(x) file.exists(file.path(site_output_dir, x$path)), articles)

  # include articles
  articles_json <- list(
    articles = articles
  )

  # include collections (if any)
  collections <- names(site_collections(site_dir, config))
  if (length(collections) > 0) {
    articles_json$collections = I(paste0(collections,"/",collections,".json"))
  } else {
    articles_json$collections = character()
  }

  # save as json
  write_articles_json(articles_json, search_json)

}

write_sitemap_xml <- function(site_dir, site_config) {

  # don't write sitemap unless we have a base_url
  if (is.null(site_config$base_url))
    return()

  # path to sitemap
  site_output_dir <- file.path(site_dir, site_config$output_dir)
  sitemap_xml <- file.path(site_output_dir, "sitemap.xml")

  # create document root
  urlset <- xml2::xml_new_root(
    "urlset",
    "xmlns" = "http://www.sitemaps.org/schemas/sitemap/0.9",
    "xmlns:xsi" = "http://www.w3.org/2001/XMLSchema-instance",
    "xsi:schemaLocation" = "http://www.sitemaps.org/schemas/sitemap/0.9 http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd",
    version = "1.0"
  )
  # add an article to the urlset
  add_article <- function(article) {
    # url
    url <- xml2::xml_add_child(urlset, "url")

    # loc
    loc <- xml2::xml_add_child(url, "loc")
    path <- sub("index.html$", "", article$path)
    xml2::xml_set_text(loc, paste0(ensure_trailing_slash(site_config$base_url), path))

    # lastmod
    lastmod <- xml2::xml_add_child(url, "lastmod")
    xml2::xml_set_text(lastmod, article$last_modified)
  }

  # enumerate articles at the top level
  input_files <- list.files(site_dir, pattern = "^[^_].*\\.[Rr]?md$")
  html_files <- lapply(input_files, function(file) {
    list(
      path = file_with_ext(file, "html"),
      last_modified = time_as_iso_8601(file.info(file.path(site_dir, file))$mtime)
    )
  })
  # filter on existence
  html_files <- Filter(function(x) file.exists(file.path(site_output_dir, x$path)),
                       html_files)

  # add articles
  lapply(html_files, add_article)

  # enumerate collections
  collections <- site_collections(site_dir, site_config)
  for (collection in collections) {
    articles_json <- file.path(site_output_dir,
                               collection$name,
                               file_with_ext(collection$name, "json"))
    if (file.exists(articles_json))
      lapply(read_json(articles_json), add_article)
  }

  # write the feed file
  xml2::write_xml(urlset, sitemap_xml)

}

write_feed_xml_html_content <- function(input_path, article, site_config) {
  html_file <- tempfile(fileext = ".html")

  # prepare source rmd
  rmd_dir <- tempfile()
  dir.create(rmd_dir)
  rmd_file <- file.path(rmd_dir, basename(input_path))
  file.copy(from = file.path(dirname(input_path), dir(dirname(input_path))),
            to = rmd_dir,
            recursive = TRUE)

  # render doc
  rmarkdown::render(rmd_file,
                    output_format = "html_fragment",
                    output_file = html_file,
                    quiet = TRUE,
                    output_options = list(
                      self_contained = FALSE,
                      section_divs = FALSE
                    ))

  # read contents
  html_contents <- paste(xfun::read_utf8(html_file), collapse = "\n")

  # fix image paths
  html_contents <- gsub(paste0(basename(dirname(rmd_file)), "/"),
                        file.path(site_config$base_url, article$path),
                        html_contents,
                        fixed = TRUE)

  html_contents
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

  namespaces <- list(
    "xmlns:atom" = "http://www.w3.org/2005/Atom",
    "xmlns:media" = "http://search.yahoo.com/mrss/",
    "xmlns:content" = "http://purl.org/rss/1.0/modules/content/",
    "xmlns:dc" = "http://purl.org/dc/elements/1.1/"
  )

  if (identical(site_config$rss$full_content, TRUE))
      namespaces <- c(namespaces, list("xmlns:distill" = "https://distill.pub/journal/"))

  # create document root
  feed <- do.call("xml_new_root", c("rss", namespaces, list(version = "2.0")), envir = asNamespace("xml2"))

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
  add_child(channel, "generator", text = "Distill")

  # last build date is date of most recent article (or now if no articles)
  last_build_date <- NULL
  if (length(articles) > 0)
    last_build_date <- articles[[1]]$date
  if (is.null(last_build_date))
    last_build_date <- Sys.Date()
  add_child(channel, "lastBuildDate", text = date_as_rfc_2822(last_build_date))

  # read all rss nodes (used for checking md5s)
  rss_nodes <- NULL
  rss_path <- file.path(site_config$output_dir, feed_xml)
  if (file.exists(rss_path)) {
    rss_nodes <- xml2::read_xml(rss_path)
  }

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

    full_content_path <- NULL
    if (identical(site_config$rss$full_content, TRUE) && is.character(article$input_file)) {
      guess_rmd <- paste0(gsub("\\.(utf|knit).*\\.md|\\.md", "", article$input_file), ".Rmd")
      full_content_path <- tryCatch(
        # will found the first file that match, which should be in a collection folder "_*"
        xfun::magic_path(guess_rmd, root = getwd(), relative = TRUE, error = TRUE, message = FALSE),
        error = function(e) {
          warning("Could not find the path ", sQuote(guess_rmd), " to build full content RSS feed for HTML page ", sQuote(article$path),
                  ". Only simple content will be inserted for this article in RSS feed.")
          NULL
        }
      )
    }

    if (length(full_content_path) > 0) {
      rss_md5 <- NULL
      if (!is.null(rss_nodes)) {
        rss_article_base <- url_path(site_config$base_url, article$path)

        rss_entry <- xml2::xml_find_all(rss_nodes, paste0("/rss/channel/item/link[text()='", rss_article_base, "']/.."))

        if ("distill" %in% names(xml2::xml_ns(rss_nodes))) {
          rss_md5 <- xml2::xml_find_all(rss_entry, "distill:md5/text()")
          rss_description <- xml2::xml_find_all(rss_entry, "description/text()")
        }
      }

      new_md5 <- openssl::md5(full_content_path)
      if (identical(rss_md5, new_md5)) {
        add_child(item, "description", text = rss_description)
      }
      else {
        html_contents <- write_feed_xml_html_content(full_content_path, article, site_config)
        add_child(item, "description", text = html_contents)
        add_child(item, "distill:md5", text = new_md5)
      }
    }
    else {
      add_child(item, "description", text = not_null_or_empty(article$description, default = article$title))
    }

    if (!is.null(article$categories)) {
      for (category in article$categories) {
        add_child(item, "category", text = category)
      }
    }

    add_child(item, "guid", text = article$base_url)
    add_child(item, "pubDate", text = date_as_rfc_2822(article$date))

    # preview image
    preview_img <- NULL
    if (length(article$preview) > 0) {
      article$preview <- absolute_preview_url(article$preview, site_config$base_url)
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
    # xml2::xml_add_child(content_encoded, xml2::xml_cdata(doRenderTags(tagList(
    #   p(article$description),
    #   p(preview_img)
    # ))))

  }

  # write the feed file
  xml2::write_xml(feed, feed_xml)

  # track the output (for moving to the _site directory later)
  add_site_output(feed_xml)

}
