


enumerate_collections <- function(site_dir, site_config, site_collections) {
  lapply(site_collections, function(collection) {
    enumerate_collection(site_dir, site_config, collection)
  })
}

enumerate_collection <- function(site_dir, site_config, collection) {

  # collection_dir
  collection_dir <- file.path(site_dir, paste0("_", collection$name))

  # ensure that it exists
  if (!dir_exists(collection_dir)) {
    dir.create(collection_dir)
  }

  # build a list of articles in the collection
  articles <- list()

  # find all html files within the collection
  html_files <- file.path(list.files(
    collection_dir,
    pattern = "^[^_].*\\.html$",
    recursive = TRUE,
    full.names = TRUE
  ))

  # find unique directories from files (only one article per directory)
  article_dirs <- unique(dirname(html_files))

  for (article_dir in article_dirs) {
    article <- published_article_from_dir(site_config, collection, article_dir)
    if (!is.null(article))
      articles[[length(articles) + 1]] <- article
  }

  # sort the articles in reverse-chronological order
  indexes <- order(sapply(articles, function(x) x$metadata$date), decreasing = TRUE)
  articles <- articles[indexes]

  # return collection
  list(
    name = collection$name,
    config = collection,
    articles = articles
  )
}


published_article_from_dir <- function(site_config, collection, article_dir) {

  # resolve to article
  article <- discover_article(article_dir)

  # bail if there was none found
  if (is.null(article))
    return(NULL)

  # bail if this is a draft
  if (isTRUE(article$metadata$draft))
    return(NULL)

  # transform metadata
  article$metadata <- transform_metadata(
    article$path,
    site_config,
    collection,
    article$metadata,
    auto_preview = TRUE
  )

  # return article
  article
}

render_collections <- function(site_dir, site_config, collections, quiet = FALSE) {

  # caching html generator
  navigation_html <- navigation_html_generator()

  # distill html (w/ theme if available)
  theme <- theme_from_site_config(site_dir, site_config)
  distill_html <- distill_in_header(theme)

  # site includes
  site_includes <- site_includes(site_dir, site_config)

  # render all collections
  lapply(collections, function(collection) {
    render_collection(
      site_dir = site_dir,
      site_config = site_config,
      collection = collection,
      navigation_html = navigation_html,
      distill_html = distill_html,
      site_includes = site_includes,
      quiet = quiet
    )
  })

}


render_collection <- function(site_dir,
                              site_config,
                              collection,
                              navigation_html,
                              distill_html,
                              site_includes,
                              quiet = FALSE) {

  if (!quiet)
    cat(paste0("\nProcessing ", collection$name, ":\n"))

  # remove and re-create output dir
  collection_output <- file.path(site_dir,
                                 site_config$output_dir,
                                 collection$name)
  if (dir_exists(collection_output))
    unlink(collection_output, recursive = TRUE)
  dir.create(collection_output, recursive = TRUE)

  # copy json output file
  file.copy(from = collection_json_path(site_dir, collection),
            to = collection_output)

  # process articles in collection
  lapply(collection$articles, function(article) {
    render_collection_article(
      site_dir = site_dir,
      site_config = site_config,
      collection = collection$config,
      article = article,
      navigation_html = navigation_html,
      distill_html = distill_html,
      site_includes = site_includes,
      strip_trailing_newline = TRUE,
      quiet = quiet
    )
  })

  if (!quiet)
    cat("\n")
}



distill_article_post_processor <- function(encoding_fn, self_contained) {

  function(metadata, input_file, output_file, clean, verbose) {

    # resolve bookdown-style figure cross references
    html_output <- xfun::read_utf8(output_file)
    html_output <- bookdown::resolve_refs_html(html_output, global = TRUE)
    xfun::write_utf8(html_output, output_file)

    # resolve encoding
    encoding <- encoding_fn()

    # run R code in metadata
    metadata <- eval_metadata(metadata)

    # is the input file at the top level of a site? if it is then no post processing
    site_config <- site_config(input_file, encoding)
    if (!is.null(site_config))
      return(output_file)

    # is the input file in a site? if not then no post processing
    site_dir <- find_site_dir(input_file)
    if (is.null(site_dir))
      return(output_file)

    # get the site config
    site_config <- site_config(site_dir, encoding)

    # is this file in a collection? if not then no post processing
    collections <- site_collections(site_dir, site_config)
    input_file_relative <- rmarkdown::relative_to(
      normalize_path(site_dir),
      normalize_path(input_file)
    )
    in_collection <- startsWith(input_file_relative, paste0("_", names(collections), "/"))
    if (!any(in_collection))
      return(output_file)

    # get the collection
    collection <- collections[[which(in_collection)]]

    # compute the article path
    article_site_path <- file.path(dirname(input_file_relative), output_file)
    article_path <- file.path(site_dir, article_site_path)

    # if this is a draft then remove any existing output folder,
    # otherwise proceed with rendering
    if (isTRUE(metadata$draft)) {

      output_dir <- collection_article_output_dir(site_dir, site_config, article_site_path)
      if (dir_exists(output_dir))
        unlink(output_dir, recursive = TRUE)

      output_file

    } else {

      # publish article
      output_file <- publish_collection_article_to_site(
        site_dir, site_config, encoding, collection, article_path, metadata,
        strip_trailing_newline = TRUE,
        input_file = input_file
      )

      # return the output_file w/ an attribute indicating that
      # base post processing should be done on both the new
      # and original output file
      structure(output_file, post_process_original = TRUE)

    }

  }
}

publish_collection_article_to_site <- function(site_dir, site_config, encoding,
                                               collection, article_path, metadata,
                                               strip_trailing_newline = FALSE,
                                               input_file = NULL) {

  # provide default date if we need to
  if (is.null(metadata[["date"]]))
    metadata$date <- date_today()

  # transform metadata for site
  metadata <- transform_metadata(
    article_path,
    site_config,
    collection,
    metadata,
    auto_preview = TRUE
  )

  # form an article object
  article <- list(
    path = article_path,
    metadata = metadata,
    input_file = input_file
  )

  # get site theme
  theme <- theme_from_site_config(site_dir, site_config)

  # render the article
  output_file <- render_collection_article(
    site_dir = site_dir,
    site_config = site_config,
    collection = collection,
    article = article,
    navigation_html = navigation_html_generator(),
    distill_html = distill_in_header(theme),
    site_includes = site_includes(site_dir, site_config),
    strip_trailing_newline = strip_trailing_newline,
    quiet = TRUE
  )

  # update the article index and regenerate listing
  update_collection_listing(site_dir, site_config, collection, article, encoding)

  # return output file
  output_file
}

# theme can either be specified @ site_config level or as an article option
theme_from_site_config <- function(site_dir, site_config) {
  theme <- site_config$theme
  if (is.null(theme)) {
    with_distill_output_options(site_config, function(output_options) {
      theme <<- output_options$theme
    })
  }
  if (!is.null(theme))
    file.path(site_dir, theme)
  else
    theme
}


read_articles_json <- function(articles_file, site_dir, site_config, collection) {
  # read the index. if there is an error (possible if the .json file e.g. is invalid
  # due to merge conflicts) then re-read the articles directly from the collection
  articles <- NULL
  if (file.exists(articles_file))
    articles <- tryCatch(read_json(articles_file), error = function(e) { NULL })
  if (is.null(articles)) {
    articles <- enumerate_collection(site_dir, site_config, collection)[["articles"]]
    articles <- to_article_info(site_dir, articles)
  }
  articles
}

move_feed_categories_xml <- function(main_feed, site_config) {
  for (category in site_config$rss$categories) {
    posts <- xml2::read_xml(main_feed)
    category_filter <- paste0("/rss/channel/item/category[text()='", category, "']/..")
    filtered <- xml2::xml_find_all(posts, category_filter)

    xml2::xml_remove(xml2::xml_find_all(posts, "/rss/channel/item"))
    channel_root <- xml2::xml_find_first(posts, "/rss/channel")
    for (entry in filtered) {
      xml2::xml_add_child(channel_root, entry)
    }

    target_path <- file.path(site_config$output_dir, "categories", tolower(category))
    if (!dir.exists(target_path)) dir.create(target_path, recursive = TRUE)

    xml2::write_xml(posts, file.path(target_path, basename(main_feed)))
  }
}

front_matter_listings <- function(input_file, encoding, full_only = FALSE) {
  metadata <- yaml_front_matter(input_file, encoding)
  if (!is.null(metadata$listing)) {
    if (is.list(metadata$listing))
      if (!full_only)
        names(metadata$listing)
      else
        c()
    else
      metadata$listing
  } else {
    c()
  }
}

update_collection_listing <- function(site_dir, site_config, collection, article, encoding,
                                      input_file) {

  # path to collection index
  collection_index <- file.path(site_dir, site_config$output_dir, collection$name,
                                paste0(collection$name, ".json"))

  # bail if there is no collection index
  if (!file.exists(collection_index))
    return()

  # read the index.
  articles <- read_articles_json(collection_index, site_dir, site_config, collection)

  # either edit the index or add a new entry at the appropriate place
  article_info <- article_info(site_dir, article)
  idx <- Position(function(x) identical(x$path, article_info$path), articles)
  if (!is.na(idx)) {
    articles[[idx]] <- article_info
  } else {
    articles[[length(articles) + 1]] <- article_info
  }

  # sort the articles in reverse-chronological order
  indexes <- order(sapply(articles, function(x) as.Date(x$date)), decreasing = TRUE)
  articles <- articles[indexes]

  # filter articles on path existing (in case of a rename)
  articles <- Filter(function(x) dir_exists(file.path(site_dir, paste0("_", x$path))),
                     articles)

  # re-write the index
  write_articles_json(articles, collection_index)

  # re-write the sitemap
  write_sitemap_xml(site_dir, site_config)

  # see if we need to re-write a listing (look an index.Rmd first then <collection>.Rmd)
  input_files <- list.files(site_dir, pattern = "^[^_].*\\.[Rr]?md$")
  input_files <- unique(c("index.Rmd", file_with_ext(collection$name, "Rmd"), input_files))
  input_files <- input_files[file.exists(file.path(site_dir, input_files))]

  # check for listings
  old_wd <- setwd(site_dir)
  on.exit(setwd(old_wd), add = TRUE)
  for (input_file in input_files) {

    # does this Rmd include a listing for this collection?
    metadata <- yaml_front_matter(input_file, encoding)
    if (!is.null(metadata$listing) && identical(metadata$listing, collection$name)) {

      # update it
      listing <- generate_listing(
        input_file,
        metadata,
        site_config,
        collection,
        articles
      )

      # move feed
      if (site_config$output_dir != "." && !is.null(listing$feed)) {
        main_feed <- file.path(site_config$output_dir, basename(listing$feed))
        file.rename(listing$feed, main_feed)

        if (!is.null(site_config$rss$categories)) {
          move_feed_categories_xml(main_feed, site_config)
        }
      }

      # replace listing html
      html_file <- file_with_ext(file.path(site_config$output_dir, input_file), "html")
      if (file.exists(html_file)) {
        html_content <- readChar(html_file,
                                 nchars = file.info(html_file)$size,
                                 useBytes = TRUE)
        Encoding(html_content) <- "UTF-8"
        listing_html <- readChar(listing$html,
                                 nchars = file.info(listing$html)$size,
                                 useBytes = TRUE)
        Encoding(listing_html) <- "UTF-8"
        listing_html <- strip_trailing_newline(listing_html)
        html_content <- fill_placeholder(html_content, "article_listing", listing_html)
        writeChar(html_content, html_file, eos = NULL, useBytes = TRUE)
      }
    }

  }

}


render_collection_article <- function(site_dir, site_config, collection, article,
                                      navigation_html, distill_html, site_includes,
                                      strip_trailing_newline = FALSE,
                                      quiet = FALSE) {

  # strip site_dir prefix
  article_site_path <- xfun::relative_path(article$path, site_dir, use.. = FALSE)

  # determine the target output dir
  output_dir <- collection_article_output_dir(site_dir, site_config, article_site_path)

  # compute offset
  offset <- collection_file_offset(article_site_path)


  # progress
  if (!quiet)
    cat(" ", dirname(article_site_path), "\n")

  # create the output directory
  if (!dir_exists(output_dir))
    dir.create(output_dir, recursive = TRUE)

  # copy files to output directory
  resources <- article$metadata$resources
  if (!is.null(resources)) {
    include <- resources$include
    exclude <- resources$exclude
  } else {
    include <- NULL
    exclude <- NULL
  }
  rmd_resources <- site_resources(
    site_dir = dirname(article$path),
    include = include,
    exclude = exclude
  )
  file.copy(from = file.path(dirname(article$path), rmd_resources),
            to = output_dir,
            recursive = TRUE,
            copy.date = TRUE)

  # rename article to index.html
  article_html <- file.path(output_dir, basename(article_site_path))
  index_html <- file.path(output_dir, "index.html")
  if (article_html != index_html)
    file.rename(article_html, index_html)

  # transform site_config and get metadata from article
  site_config <- transform_site_config(site_config)
  metadata <- article$metadata

  # read index content
  index_content <- readChar(index_html,
                            nchars = file.info(index_html)$size,
                            useBytes = TRUE)
  Encoding(index_content) <- "UTF-8"


  # get rmarkdown metadata
  rmarkdown_metadata <- extract_embedded_metadata(index_html)

  # pickup canonical and citation urls
  rmarkdown_metadata$citation_url <- metadata$citation_url
  rmarkdown_metadata$canonical_url <- metadata$canonical_url

  # pickup creative_commons from site/collection
  if (is.null(rmarkdown_metadata[["creative_commons"]])) {
    rmarkdown_metadata <- merge_metadata(site_config, collection, rmarkdown_metadata,
                                         fields = c("creative_commons"))
  }

  # re-write
  index_content <- fill_placeholder(
    index_content,
    "rmarkdown_metadata",
    doRenderTags(embedded_metadata_html(rmarkdown_metadata))
  )

  # substitute meta tags
  metadata_html <- metadata_html(site_config, metadata, self_contained = FALSE, offset = offset)
  index_content <- fill_placeholder(index_content,
                                    "meta_tags",
                                    doRenderTags(metadata_html))

  # substitute front_matter
  index_content <- fill_placeholder(index_content,
                                    "front_matter",
                                    doRenderTags(front_matter_html(metadata)))

  # substitue appendices
  appendices_html <- appendices_after_body_html(article$path, site_config, metadata)
  index_content <- fill_placeholder(index_content,
                                    "appendices",
                                    doRenderTags(appendices_html))

  # substitute navigation html
  navigation <- navigation_html(site_dir, site_config, offset)
  apply_navigation <- function(content, context) {
    fill_placeholder(content, paste0("navigation_", context), navigation[[context]])
  }
  index_content <- apply_navigation(index_content, "in_header")
  index_content <- apply_navigation(index_content, "before_body")
  index_content <- apply_navigation(index_content, "after_body")

  # substitute distill_html
  index_content <- fill_placeholder(index_content, "distill", distill_html)

  # substitute site includes
  apply_site_include <- function(content, context) {
    fill_placeholder(content, paste0("site_", context), site_includes[[context]])
  }
  index_content <- apply_site_include(index_content, "in_header")
  index_content <- apply_site_include(index_content, "before_body")
  index_content <- apply_site_include(index_content, "after_body")

  # categories
  index_content <- fill_placeholder(index_content, "categories", placeholder_html(
    "categories", categories_html(site_dir, collection, offset, article)
  ))

  # article footer
  index_content <- fill_placeholder(index_content, "article_footer", placeholder_html(
    "article_footer", article_footer_html(site_dir, site_config, collection, article)
  ))

  # resolve site_libs
  site_libs <- file.path(site_dir, site_config$output_dir, "site_libs")
  if (!dir_exists(site_libs))
    dir.create(site_libs, recursive = TRUE)
  index_content <- apply_site_libs(index_content, article_html, site_libs, offset)

  # remove carriage returns
  index_content <- gsub("\r\n", "\n", index_content, useBytes = TRUE)

  # strip trailing newline if requested (this is necessary so that we can ensure
  # that incremental vs. render_site output is identical so as to not generate
  # spurious diffs)
  if (strip_trailing_newline)
    sep = ""
  else
    sep = "\n"

  # write the content
  writeLines(index_content, index_html, sep = sep, useBytes = TRUE)

  # return path to rendered article
  index_html
}

categories_html <- function(site_dir, collection, offset, article) {

  if (!is.null(article$metadata$categories)) {

    # see if there is a listings page we can point categories at
    listings_page_html <- NULL
    input_files <- list.files(site_dir, pattern = "^[^_].*\\.[Rr]?md$")
    for (file in input_files) {
      file_path = file.path(site_dir, file)
      listings <- front_matter_listings (file_path, "UTF-8", TRUE)
      if (collection$name %in% listings) {
        listings_page_html <- file_with_ext(file, "html")
        break
      }
    }

    # generate categories
    if (!is.null(listings_page_html)) {
      div(class = "dt-tags",
        lapply(article$metadata$categories, function(category) {
          href <- paste0(offset, "/", listings_page_html, category_hash(category))
          a(href = href, class = "dt-tag", category)
        })
      )

    } else {
      NULL
    }
  } else {
    NULL
  }
}

article_footer_html <- function(site_dir, site_config, collection, article) {

  base_url <- site_config[["base_url"]]

  disqus_options <- collection[["disqus"]]
  disqus_class <- NULL
  if (is.list(disqus_options)) {
    disqus_shortname <- disqus_options[["shortname"]]
    if (identical(not_null(disqus_options[["hidden"]], TRUE), TRUE))
      disqus_class <- "hidden"
  } else {
    disqus_shortname <- disqus_options
    disqus_class <- "hidden"
  }

  share_services <- collection[["share"]]

  # validate base_url if needed
  if (!is.null(disqus_shortname) && is.null(base_url))
    stop("You must specify a base_url when including disqus comments.", call. = FALSE)
  if (!is.null(share_services) && is.null(base_url))
    stop("You must specify a base_url when including sharing links", call. = FALSE)

  # bail if there is no base_url
  if (is.null(base_url))
    return(NULL)


  # article info
  article_title <- article$metadata$title
  encoded_article_title <- utils::URLencode(article_title, reserved = TRUE)
  article_url <- ensure_trailing_slash(article$metadata$base_url)
  encoded_article_url <- utils::URLencode(article_url, reserved = TRUE)
  article_id <- sub(paste0("^", ensure_trailing_slash(base_url)), "", article_url)

  # function to create a sharing link for a service
  sharing_link <- function(service) {
    switch(service,
      twitter = sprintf("https://twitter.com/share?text=%s&url=%s",
                        encoded_article_title, encoded_article_url) ,
      facebook = sprintf("https://www.facebook.com/sharer/sharer.php?s=100&p[url]=%s",
                         encoded_article_url),
      `google-plus` = sprintf("https://plus.google.com/share?url=%s",
                              encoded_article_url),
      linkedin = sprintf("https://www.linkedin.com/shareArticle?mini=true&url=%s&title=%s",
                         encoded_article_url, encoded_article_title),
      pinterest = sprintf("https://pinterest.com/pin/create/link/?url=%s&description=%s",
                         encoded_article_url, encoded_article_title)
    )
  }


  # share
  share <- NULL
  if (!is.null(share_services)) {

    # filter out invalid sites
    share_services <- match.arg(share_services,
                                c("twitter", "facebook", "google-plus",
                                  "linkedin", "pinterest"),
                                several.ok = TRUE)

    share <- tags$span(class = "article-sharing",
      HTML("Share: &nbsp;"),
      tagList(lapply(share_services, function(service) {
        tags$a(href = sharing_link(service), `aria-label` = sprintf("share on %s", service),
          tag("i", list(class = sprintf("fab fa-%s", service), `aria-hidden` = "true"))
        )
      }))
    )
  }

  # disqus
  disqus <- NULL
  disqus_script <- NULL

  if (!is.null(disqus_shortname)) {
    disqus <- tags$span(class = "disqus-comments",
      tag("i", list(class = "fas fa-comments")),
      HTML("&nbsp;"),
      tags$span(class = "disqus-comment-count", `data-disqus-identifier` = article_id,
              "Comment on this article")
    )

    disqus_script <- tagList(

      tags$script(id = "dsq-count-scr",
                  src = sprintf("https://%s.disqus.com/count.js", disqus_shortname),
                  async = NA),

      tags$div(id = "disqus_thread", class = disqus_class),

      tags$script(type = cc_check(site_config),
                  `cookie-consent` = "functionality",
        HTML(paste(sep = "\n",
          sprintf(paste(sep = "\n",
              "\nvar disqus_config = function () {",
              "  this.page.url = '%s';",
              "  this.page.identifier = '%s';",
              "};"), article_url, article_id),
          "(function() {",
          "  var d = document, s = d.createElement('script');",
          sprintf("  s.src = 'https://%s.disqus.com/embed.js';", disqus_shortname),
          "  s.setAttribute('data-timestamp', +new Date());",
          "  (d.head || d.body).appendChild(s);",
          "})();\n"
      )))
    )
  }

  # aggregate social
  social <- NULL
  if (!is.null(disqus) || !is.null(share)) {
    social <- tagList(
      tags$p(class = "social_footer", disqus, share),
      disqus_script
    )
  }

  # look for subscription html
  subscription <- subscription_html(site_dir, collection)
  if (!is.null(subscription)) {
    subscription <- tags$p(tags$div(class = "subscribe", subscription))
  }

  # render html
  if (!is.null(disqus) || !is.null(share) || !is.null(subscription)) {
    doRenderTags(div(class = "article-footer", social, subscription))
  } else {
    NULL
  }
}

strip_trailing_newline <- function(x) {
  if (grepl("\n$", x))
    substring(x, 1, nchar(x) - 1)
  else
    x
}

collection_article_output_dir <- function(site_dir, site_config, article_site_path) {
  file.path(site_dir,
            site_config$output_dir,
            sub("^_", "", dirname(article_site_path)))
}

apply_site_libs <- function(index_content, article_path, site_libs, offset) {

  # find _files directories referenced from script and link tags
  files_dir <- knitr_files_dir(basename(article_path))
  pattern <- sprintf('((?:<script src=|<link href=)")(%s)(/[^/]+/)', files_dir)
  match <- gregexpr(pattern, index_content, useBytes = TRUE)
  dirs <- sapply(strsplit(regmatches(index_content, match)[[1]], split = "/"), `[[`, 2)
  dirs <- unique(dirs)

  # move the directories to site_libs as necessary
  for (dir in dirs) {
    article_lib_dir <- file.path(dirname(article_path), files_dir, dir)
    site_lib_dir <- file.path(site_libs, dir)
    if (!dir_exists(site_lib_dir))
      file.rename(article_lib_dir, site_lib_dir)
    else
      unlink(article_lib_dir, recursive = TRUE)
  }

  # fixup html
  gsub(pattern,
       sprintf("\\1%s/%s\\3", offset, basename(site_libs)),
       index_content,
       useBytes = TRUE)
}


discover_article <- function(article_dir) {

  article_html <- NULL
  article_metadata <- NULL

  html_files <- list.files(path = article_dir,
                           pattern = "^[^_].*\\.html$",
                           full.names = TRUE)

  if (length(html_files) == 1) {

    # just one html file
    article_html <- html_files[[1]]

  } else {

    # more than one: look for an index
    index <- which(tolower(basename(html_files)) == "index.html")
    if (length(index) > 0) {
      article_html <- html_files[[index[1]]]
    }

    # look for first one that has metadata in it
    else {
      for (html_file in html_files) {
        article_metadata <- extract_embedded_metadata(html_file)
        if (!is.null(article_metadata)) {
          article_html <- html_file
          break
        }
      }
    }
  }

  if (!is.null(article_html)) {

    # complete metadata
    if (is.null(article_metadata))
      article_metadata <- extract_embedded_metadata(article_html)

    # return if we have metadata
    if (!is.null(article_metadata)) {
      list(
        path = article_html,
        metadata = article_metadata
      )
    } else {
      NULL
    }
  } else {
    NULL
  }
}



write_collections_metadata <- function(site_dir, collections) {
  for (collection in collections)
    write_collection_metadata(site_dir, collection)
}


write_collection_metadata <- function(site_dir, collection) {

  # tranform to article info
  articles <- to_article_info(site_dir, collection[["articles"]])

  # write
  write_articles_json(articles, collection_json_path(site_dir, collection))

}

to_article_info <- function(site_dir, articles) {
  lapply(articles, function(article) {
    article_info(site_dir, article)
  })
}

write_articles_json <- function(articles, path) {
  json <- jsonlite::toJSON(articles, pretty = TRUE, auto_unbox = TRUE)
  json <- paste0(json, "\n")
  writeLines(json, path, sep = "", useBytes = TRUE)
}

article_contents <- function(path) {
  contents <- ""
  html <- xml2::read_html(path)
  article_html <- xml2::xml_find_first(
    html,
    "descendant-or-self::*[(@class and contains(concat(' ', normalize-space(@class), ' '), ' d-article '))]"
  )
  if (is.na(article_html)) {
    article_html <- xml2::xml_find_first(html, "//body")
  }
  if (!is.na(article_html)) {
    # remove script tag content for article content
    scripts <- xml2::xml_find_all(article_html, "//script")
    xml2::xml_remove(scripts)
    # remove style tag content for article content
    style <- xml2::xml_find_all(article_html, "//style")
    xml2::xml_remove(style)

    contents <- as_utf8(xml2::xml_text(article_html))
  }
  contents
}

article_info <- function(site_dir, article) {

  # read article contents
  contents <- article_contents(article$path)

  path <- as_utf8(paste0(url_path(article_site_path(site_dir, article$path)), "/"))
  info <- list(
    path = as_utf8(path),
    title = as_utf8(article$metadata$title),
    description = as_utf8(article$metadata$description),
    author = lapply(article$metadata$author, function(author) {
      list(
        name = as_utf8(author$name),
        url = author$url
      )
    }),
    date = article$metadata$date,
    categories = as.list(article$metadata$categories),
    contents = as_utf8(contents),
    preview = resolve_preview_url(article$metadata$preview, path),
    last_modified = time_as_iso_8601(file.info(article$path)$mtime),
    input_file = article$input_file
  )

  info$preview_width <- article$metadata$preview_width
  info$preview_height <- article$metadata$preview_height

  info
}


remove_collections_metadata <- function(site_dir, collections) {
  for (collection in collections)
    remove_collection_metadata(site_dir, collection)
}

remove_collection_metadata <- function(site_dir, collection) {
  file.remove(collection_json_path(site_dir, collection))
}

collection_json_path <- function(site_dir, collection) {
  name <- collection[["name"]]
  file.path(
    site_dir,
    paste0("_", name),
    file_with_ext(name, ext = "json")
  )
}


site_collections <- function(site_dir, site_config) {

  # collections defined in file
  collections <- site_config[["collections"]]
  if (is.null(collections))
    collections <- list()
  else if (is.character(collections)) {
    collection_names <- names(collections)
    collections <- lapply(collections, function(collection) {
      list()
    })
    names(collections) <- collection_names
  }
  else if (is.list(collections)) {
    if (is.null(names(collections)))
      stop('Site collections must be specified as a named list', call. = FALSE)
  }

  # automatically include posts and articles
  ensure_collection <- function(name) {
    if (!name %in% names(collections))
      collections[[name]] <<- list()
  }
  ensure_collection("posts")
  ensure_collection("articles")

  # add any collection with a listing
  input_files <- list.files(site_dir, pattern = "^[^_].*\\.[Rr]?md$", full.names = TRUE)
  sapply(input_files, function(file) {
    listings <- front_matter_listings(file, "UTF-8")
    sapply(listings, ensure_collection)
  })

  # filter on directory existence
  collections <- collections[file.exists(file.path(site_dir, paste0("_", names(collections))))]

  # add name field
  for (name in names(collections))
    collections[[name]][["name"]] <- name

  # inherit some properties from the site
  lapply(collections, function(collection) {
    inherit_prop <- function(name) {
      if (is.null(collection[[name]]))
        collection[[name]] <<- site_config[[name]]
    }
    inherit_prop("title")
    inherit_prop("description")
    inherit_prop("copyright")
    collection
  })

}


collection_file_offset <- function(file) {
  offset_dirs <- length(strsplit(file, "/")[[1]]) - 1
  paste(rep_len("..", offset_dirs), collapse = "/")
}


article_site_path <- function(site_dir, article) {
  article_relative <- rmarkdown::relative_to(
    normalize_path(site_dir),
    normalize_path(article)
  )
  article_relative <- sub("^_", "", article_relative)
  dirname(article_relative)
}



