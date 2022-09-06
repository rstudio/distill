

transform_configuration <- function(file, site_config, collection_config, metadata, auto_preview) {

  # transform site_config and metadata values
  site_config <- transform_site_config(site_config)
  metadata <- transform_metadata(file, site_config, collection_config, metadata, auto_preview)

  list(
    site_config = site_config,
    metadata = metadata
  )
}

transform_site_config <- function(site_config) {

  if (!is.null(site_config) && length(site_config) > 0) {

    # propagate navbar title to main title
    if (is.null(site_config$title) && !is.null(site_config$navbar))
      site_config$title <- site_config$navbar$title

    # propagate main title to navbar title
    if (!is.null(site_config$title) && !is.null(site_config$navbar)
        && is.null(site_config$navbar$title)) {
      site_config$navbar$title <- site_config$title
    }

    # validate that we have a title
    if (is.null(site_config$title))
      stop("_site.yml must include a title field", call. = FALSE)
  }

  site_config
}

transform_metadata <- function(file, site_config, collection_config, metadata, auto_preview) {

  # validate title
  if (is.null(metadata$title))
    metadata$title <- "Untitled"

  # trim ws from description
  if (!is.null(metadata$description))
    metadata$description <- trimws(metadata$description)

  # if the site has a base_url then we need to tweak the base url of the
  # input document to use the site
  if (!is.null(site_config[["base_url"]])) {
    base_url <- strip_trailing_slash(site_config$base_url)
    site_dir <- find_site_dir(file)
    article_path <- article_site_path(site_dir, file)
    metadata$base_url <- url_path(base_url, article_path)
  }

  # merge site and collection level metadata
  metadata <- merge_metadata(site_config, collection_config, metadata,
                             fields = c("repository_url", "creative_commons",
                                        "twitter", "favicon"))


  # see if we can determine a default canonical_url
  canonical_url_fields <- c("canonical_url", "citation_url", "base_url")
  default_canonical_url <- metadata[canonical_url_fields]
  default_canonical_url <- default_canonical_url[!is.na(names(default_canonical_url))]
  if (length(default_canonical_url) > 0)
    default_canonical_url <- ensure_trailing_slash(default_canonical_url[[1]])
  else
    default_canonical_url <- NULL

  # provide some urls automagically for collections
  if (length(collection_config) > 0 && !is.null(default_canonical_url)) {

    # automatically provide canonical_url if possible and permitted
    if (is.null(metadata[["canonical_url"]]) &&
        not_null(collection_config[["canonical"]], TRUE)) {
      metadata$canonical_url <- default_canonical_url
    }

    # automatically provide citation_url if possible and permitted
    if (is.null(metadata[["citation_url"]]) &&
        not_null(collection_config[["citations"]], TRUE)) {
      metadata$citation_url <- default_canonical_url
    }
  }

  # parse dates
  article_dir <- basename(normalize_path(dirname(file)))
  metadata$date <- resolve_date(article_dir, metadata$date)
  metadata$updated <- parse_date(metadata$updated)

  if (!is.null(metadata$date)) {

    metadata$published_year <- format(metadata$date, "%Y")
    months <- c('Jan.', 'Feb.', 'March', 'April', 'May', 'June',
                'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.')
    metadata$published_month <- months[[as.integer(format(metadata$date, "%m"))]]
    metadata$published_day <- as.integer(format(metadata$date, "%d"))
    metadata$published_month_padded <- format(metadata$date, "%m")
    metadata$published_day_padded <- format(metadata$date, "%d")
    metadata$published_date_rfc <- date_as_rfc_2822(metadata$date)
    if (!is.null(metadata$updated))
      metadata$updated_date_rfc <- date_as_rfc_2822(metadata$updated)
    metadata$published_iso_date_only <- date_as_iso_8601(metadata$date, date_only = TRUE)
  }

  # normalize journal (for citations)
  if (!is.null(metadata$journal)) {
    if (is.character(metadata$journal))
      metadata$journal <- list(title = metadata$journal)
  } else {
    metadata$journal <- list()
  }

  # normalize conference (for citations)
  if (!is.null(metadata$conference)) {
    if (is.character(metadata$conference))
      metadata$conference <- list(title = metadata$conference)
  } else {
    metadata$conference <- list()
  }

  # normalize thesis (for citations). This entry does need thesis type (e.g., "phd" or "masters") instead of title since thesis will use default page title.
  if (!is.null(metadata$thesis)) {
    if (is.character(metadata$thesis))
      metadata$thesis <- list(type = metadata$thesis)
  } else {
    metadata$thesis <- list()
  }

  # normalize technical_report (for citations). This entry only requires a list as a normalized base.
  if (length(metadata$technical_report) == 0) {
  metadata$technical_report <- list()
  }

  # resolve creative commons license
  if (!is.null(metadata$creative_commons)) {

    # validate
    valid_licenses <- c("CC BY", "CC BY-SA", "CC BY-ND", "CC BY-NC",
                        "CC BY-NC-SA", "CC BY-NC-ND", "CC0")
    if (!metadata$creative_commons %in% valid_licenses) {
      stop("creative_commonds license must be one of ",
           paste(valid_licenses, collapse = ", "))
    }

    # compute license url
    metadata$license_url <- creative_commons_url(metadata$creative_commons)
  }

  # base_url (strip trailing slashes)
  if (!is.null(metadata$base_url))
    metadata$base_url <- strip_trailing_slash(metadata$base_url)

  # if there is no preview see if we can impute one from preview=TRUE on a chunk
  if (is.null(metadata$preview) && auto_preview)
    metadata$preview <- discover_preview(file)

  # file based preview image
  if (!is.null(metadata$preview) && !is_url(metadata$preview)) {

    # compute the path on disk
    metadata_path <- file.path(dirname(file), metadata$preview)

    # if the file doesn't exist then see if we can auto-discover a preview
    if (!file.exists(metadata_path)) {
      metadata$preview <- NULL
      if (auto_preview) {
        metadata$preview <- discover_preview(file)
        if (!is.null(metadata$preview))
          metadata_path <- file.path(dirname(file), metadata$preview)
      }
    }

    # resolve preview url
    if (!is.null(metadata$preview) && !is.null(metadata$base_url)) {

      # compute preview url
      metadata$preview_url <- url_path(metadata$base_url, metadata$preview)

      # if it's a png then determine it's dimensions
      if (is_file_type(metadata_path, "png")) {
        png <- png::readPNG(metadata_path)
        metadata$preview_width <- ncol(png)
        metadata$preview_height <- nrow(png)
      }
    }
  }

  # authors
  if (!is.null(metadata$author)) {

    # convert to list if necessary
    metadata$author <- fixup_author(metadata$author)

    # compute first and last name
    metadata$author <- authors_with_first_and_last_names(metadata$author)

    # compute concatenated authors
    metadata$concatenated_authors <-
      if (length(metadata$author) > 2)
        paste0(metadata$author[[1]]$last_name, ', et al.')
    else if (length(metadata$author) == 2)
      paste(metadata$author[[1]]$last_name, '&', metadata$author[[2]]$last_name)
    else if (length(metadata$author) == 1)
      metadata$author[[1]]$last_name

    # compute bibtex authors
    metadata$bibtex_authors <- bibtex_authors(metadata$author)

    # slug
    if (is.null(metadata$slug) && !is.null(metadata$date)) {
      metadata$slug <- paste0(
        tolower(gsub(" ", "", metadata$author[[1]]$last_name, fixed = TRUE)),
        metadata$published_year,
        tolower(strsplit(metadata$title, ' ')[[1]][[1]])
      )
    }
  }

  # default lang
  if (is.null(metadata$lang))
    metadata$lang <- "en_US"

  # failsafe for slug
  if (is.null(metadata$slug))
    metadata$slug <- "Untitled"

  metadata
}

metadata_html <- function(site_config, metadata, self_contained, offset = NULL) {

  offset_href <- function(href) {
    if (is.null(href))
      NULL
    else if (!is.null(offset) && !is_url(href))
      file.path(offset, href)
    else
      href
  }

  # title
  title <- list()
  qualified_title <- qualified_title(site_config, metadata)
  if (!is.null(qualified_title))
    title <- tags$title(qualified_title)

  # description
  description_meta <- list()
  if (!is.null(metadata$description)) {
    description_meta[[1]] <- tags$meta(
      property="description", itemprop="description", content=metadata$description
    )
  }

  # links
  links <- list()
  if (!is.null(metadata$canonical_url)) {
    links[[1]] <- tags$link(
      rel = "canonical",
      href = metadata$canonical_url
    )
  }
  if (!self_contained) {
    if (!is.null(metadata$license_url)) {
      links[[length(links) + 1]] <- tags$link(
        rel = "license",
        href = metadata$license_url
      )
    }
  }
  if (!is.null(metadata$favicon)) {
    links[[length(links) + 1]] <- tags$link(
      rel = "icon",
      type = mime::guess_type(metadata$favicon),
      href = offset_href(metadata$favicon)
    )
  }


  # authors meta tags
  author_meta <- lapply(metadata$author, function(author) {
    tags$meta(name="article:author", content=author$name)
  })

  article_meta <- list()
  if (!is.null(metadata$date)) {
    date <- format.Date(metadata$date, "%Y-%m-%d")
    article_meta <- tagList(
      HTML("<!--  https://schema.org/Article -->"),
      tags$meta(property="article:published", itemprop="datePublished", content=date),
      tags$meta(property="article:created", itemprop="dateCreated", content=date)
    )
  }

  # updated date
  updated_meta <- list()
  if (!is.null(metadata$updated)) {
    updated <-  date_as_iso_8601(metadata$updated)
    updated_meta[[1]] <- tags$meta(
      property="article:modified", itemprop="dateModified", content=updated
    )
  }

  # open graph (https://developers.facebook.com/docs/sharing/webmasters#markup)
  open_graph_meta <- open_graph_metadata(site_config, metadata)

  # twitter card (https://dev.twitter.com/cards/types/summary)
  twitter_card_meta <- twitter_card_metadata(site_config, metadata)

  # google scholar (https://scholar.google.com/intl/en/scholar/inclusion.html)
  google_scholar_meta <- google_scholar_metadata(site_config, metadata)

  # render head tags
  meta_tags <- do.call(tagList, list(
    title,
    HTML(''),
    description_meta,
    HTML(''),
    links,
    HTML(''),
    article_meta,
    updated_meta,
    author_meta,
    HTML(''),
    open_graph_meta,
    HTML(''),
    twitter_card_meta,
    HTML(''),
    google_scholar_meta
  ))
  placeholder_html("meta_tags", meta_tags)
}

metadata_in_header <- function(site_config, metadata, self_contained) {
  meta_tags <- metadata_html(site_config, metadata, self_contained)
  meta_html <- doRenderTags(meta_tags)
  meta_file <- tempfile(fileext = "html")
  writeLines(meta_html, meta_file, useBytes = TRUE)
  meta_file
}


open_graph_metadata <- function(site_config, metadata) {

  # core descriptors
  open_graph_meta <- list(
    HTML("<!--  https://developers.facebook.com/docs/sharing/webmasters#markup -->"),
    tags$meta(property = "og:title", content = qualified_title(site_config, metadata)),
    tags$meta(property = "og:type", content = "article")
  )

  # add a property
  add_open_graph_meta <- function(property, content) {
    if (!is.null(content)) {
      open_graph_meta[[length(open_graph_meta)+1]] <<-
        tags$meta(property = property, content = content)
    }
  }

  # description
  add_open_graph_meta("og:description", metadata$description)

  # cannonical url
  add_open_graph_meta("og:url", metadata$canonical_url)

  # preivew/thumbnail url
  add_open_graph_meta("og:image", metadata$preview_url)
  add_open_graph_meta("og:image:width", metadata$preview_width)
  add_open_graph_meta("og:image:height", metadata$preview_height)

  # locale
  add_open_graph_meta("og:locale", metadata$lang)

  # site name
  add_open_graph_meta("og:site_name", site_config$title)

  open_graph_meta
}

twitter_card_metadata <- function(site_config, metadata) {

  twitter_card_meta <- list(
    HTML("<!--  https://dev.twitter.com/cards/types/summary -->")
  )

  # add a property
  add_twitter_card_meta <- function(property, content) {
    if (!is.null(content)) {
      twitter_card_meta[[length(twitter_card_meta)+1]] <<-
        tags$meta(property = property, content = content)
    }
  }

  # card type
  card_type <- if(!is.null(metadata$preview_url)) "summary_large_image" else "summary"
  add_twitter_card_meta("twitter:card", card_type)

  # title and description
  add_twitter_card_meta("twitter:title", qualified_title(site_config, metadata))
  add_twitter_card_meta("twitter:description", metadata$description)

  # cannonical url
  add_twitter_card_meta("twitter:url", metadata$canonical_url)

  # preview image
  add_twitter_card_meta("twitter:image", metadata$preview_url)
  add_twitter_card_meta("twitter:image:width", metadata$preview_width)
  add_twitter_card_meta("twitter:image:height", metadata$preview_height)

  # twitter attribution
  if (!is.null(metadata$twitter)) {
    add_twitter_card_meta("twitter:site", metadata$twitter$site)
    add_twitter_card_meta("twitter:creator", metadata$twitter$creator)
  }

  twitter_card_meta
}

# see https://github.com/scieloorg/opac/files/1136749/Metatags.for.Bibliographic.Metadata.Google.Scholar.-.COMPLETE.pdf

google_scholar_metadata <- function(site_config, metadata) {

  # empty if not citable
  if (!is_citeable(metadata))
    return(list())

  google_scholar_meta <- list(
    HTML("<!--  https://scholar.google.com/intl/en/scholar/inclusion.html#indexing -->"),
    tags$meta(name = "citation_title", content = qualified_title(site_config, metadata))
  )

  # helper to add properties
  add_meta <- function(property, content) {
    if (!is.null(content)) {
      google_scholar_meta[[length(google_scholar_meta)+1]] <<-
        tags$meta(name = property, content = content)
    }
  }

  add_meta("citation_fulltext_html_url", metadata$citation_url)
  add_meta("citation_pdf_url", metadata$pdf_url)
  add_meta("citation_volume", metadata$volume)
  add_meta("citation_issue", metadata$issue)
  add_meta("citation_doi", metadata$doi)
  add_meta("citation_isbn", metadata$isbn)
  journal <- metadata$journal
  if(length(journal) != 0) {
    journal_title <- if (!is.null(journal$full_title) )
      journal$full_title
    else
      journal$title
    add_meta("citation_journal_title", journal$title)
    add_meta("citation_journal_abbrev", journal$abbrev_title)
    add_meta("citation_issn", journal$issn)
    add_meta("citation_publisher", journal$publisher)
    add_meta("citation_firstpage", journal$firstpage)
    add_meta("citation_lastpage", journal$lastpage)
  }
  conference <- metadata$conference
  if(length(conference) != 0) {
    conference_title <- if (!is.null(conference$full_title) )
      conference$full_title
    else
      conference$title
    add_meta("citation_conference_title", conference$title)
    add_meta("citation_issn", conference$issn)
    add_meta("citation_publisher", conference$publisher)
    add_meta("citation_firstpage", conference$firstpage)
    add_meta("citation_lastpage", conference$lastpage)
  }
  if (!is.null(metadata$creative_commons))
    add_meta("citation_fulltext_world_readable", "")
  citation_date <- sprintf("%s/%s/%s",
                           metadata$published_year,
                           metadata$published_month_padded,
                           metadata$published_day_padded
  )
  add_meta("citation_online_date", citation_date);
  add_meta("citation_publication_date", citation_date);
  for (author in metadata$author) {
    add_meta("citation_author", author$name)
    add_meta("citation_author_institution", author$affiliation)
  }
  thesis <- metadata$thesis
  if(length(thesis) != 0) {
    for (author in metadata$author) {
      add_meta("citation_dissertation_institution", author$affiliation)
    }
    add_meta("citation_issn", thesis$issn)
    add_meta("citation_publisher", thesis$publisher)
    add_meta("citation_firstpage", thesis$firstpage)
    add_meta("citation_lastpage", thesis$lastpage)
  }
  technical_report <- metadata$technical_report
  if(length(technical_report) != 0) {
    for (author in metadata$author) {
      add_meta("citation_technical_report_institution", author$affiliation)
    }
    add_meta("citation_technical_report_number", technical_report$number)
    add_meta("citation_issn", technical_report$issn)
    add_meta("citation_publisher", technical_report$publisher)
    add_meta("citation_firstpage", technical_report$firstpage)
    add_meta("citation_lastpage", technical_report$lastpage)
  }

  google_scholar_meta
}

citation_references_in_header <- function(file, bibliography) {

  if (!is.null(bibliography)) {

    # pandoc friendly bibliography path
    bibliography <- pandoc_path_arg(bibliography)

    # first generate html with all of the citations
    biblio_html <- tempfile(fileext = "html")
    pandoc_convert(file, to = "html5", from = "markdown-tex_math_dollars", output = biblio_html,
                   citeproc = TRUE, options = list(
                     "--bibliography", bibliography,
                     "--template", pandoc_path_arg(distill_resource("biblio.html"))
                   ))

    # parse the html for citations
    biblio <- xml2::read_html(
      readChar(biblio_html, nchars = file.info(biblio_html)$size, useBytes = TRUE)
    )
    citations <- xml2::xml_find_all(biblio, "//span[@data-cites]")
    citations <- unique(xml2::xml_attr(citations, "data-cites"))

    citation_ids <- c()
    lapply(citations, function(citation) {
      citation_ids <<- c(citation_ids, strsplit(citation, " ", TRUE)[[1]])
    })
    citation_ids <- unique(citation_ids)

    # generate meta tags
    references <- tagList(HTML(''), lapply(pandoc_citeproc_convert(bibliography), function(ref) {
      if (ref$id %in% citation_ids)
        tags$meta(name = "citation_reference", content = citation_reference(ref))
    }))

    html_file(references)

  } else {
    c()
  }

}

citation_reference <- function(ref) {

  # collect fields
  names <- c()
  values <- c()
  add_field <- function(name, value)  {
    if (!is.null(value)) {
      names <<- c(names, name)
      values <<- c(values, value)
    }
  }
  add_ref_field <- function(name) {
    add_field(name, ref[[name]])
  }
  add_ref_field("title")
  if (length(ref$issued$`date-parts`) > 1)
    add_field("publication_date", ref[["issued"]][["date-parts"]][[1]][[1]])
  add_ref_field("publisher")

  # TODO: arxiv test  here
  add_field("journal_title", ref[["journal"]])
  add_ref_field("volume")
  add_ref_field("number")

  add_field("doi", ref[["DOI"]])
  add_field("issn", ref[["ISSN"]])
  if (!is.null(ref[["author"]])) {
    for (author in ref$author)
      add_field("author", paste(author[["given"]], author[["family"]]))
  }

  # prepend 'citation'
  names <- paste0("citation_", names)

  # combine name & value
  fields <- paste(names, values, sep = "=")
  paste(fields, collapse = ";")
}

is_citeable <- function(metadata) {
  !is.null(metadata$date) &&
    !is.null(metadata$author) &&
    !identical(metadata[["citation"]], FALSE) &&
    (!is.null(metadata$citation_url) || !is.null(metadata$journal$title))
}

front_matter_from_metadata <- function(metadata) {
  front_matter <- list()
  front_matter$title <- metadata$title
  front_matter$description <- metadata$description
  front_matter$doi <- metadata$doi
  front_matter$authors <- lapply(metadata$author, function(author) {
    list(
      author = author$name,
      authorURL = not_null(author$url, "#"),
      affiliation = not_null(author$affiliation, "&nbsp;"),
      affiliationURL = not_null(author$affiliation_url, "#"),
      orcidID = not_null(author$orcid_id, "")
    )
  })
  if (!is.null(metadata$date)) {
    if (is.character(metadata$date))
      metadata$date <- parse_date(metadata$date)
    front_matter$publishedDate <- date_as_iso_8601(metadata$date)
  }
  if (!is.null(metadata$concatenated_authors) && !is.null(metadata$published_year)) {
    front_matter$citationText <- sprintf("%s, %s",
                                         metadata$concatenated_authors,
                                         metadata$published_year)
  }
  jsonlite::toJSON(front_matter, auto_unbox = TRUE)
}

front_matter_html <- function(metadata) {
  placeholder_html("front_matter",
    HTML(paste(c(
     '',
     '<script id="distill-front-matter" type="text/json">',
     front_matter_from_metadata(metadata),
     '</script>',
     '') ,collapse = "\n")
    )
  )
}

front_matter_before_body <- function(metadata) {
  html_file(front_matter_html(metadata))
}

embedded_metadata <- function(metadata) {
  html_file(embedded_metadata_html(metadata))
}

embedded_metadata_html <- function(metadata) {
  json_html <- embedded_json(metadata, "radix-rmarkdown-metadata", file = NULL)
  placeholder_html("rmarkdown_metadata", json_html)
}

extract_embedded_metadata <- function(file) {
  metadata <- extract_embedded_json(file, "radix-rmarkdown-metadata")
  if (!is.null(metadata$description))
    metadata$description <- trimws(metadata$description)
  metadata$author <- fixup_author(metadata$author)
  metadata
}

embedded_json <- function(x, id, file = tempfile(fileext = "html")) {

  # generate json
  json <- jsonlite::serializeJSON(x)
  lines <- c('',
             paste0('<script type="text/json" ', 'id="', id ,'">'),
             # escape json, see https://github.com/rstudio/rmarkdown/issues/943
             gsub("</", "<\\u002f", json, fixed = TRUE),
             '</script>')

  if (!is.null(file)) {
    # append to the file (guaranteed to be UTF-8)
    con <- file(file, open = "w", encoding = "UTF-8")
    on.exit(close(con), add = TRUE)
    writeLines(lines, con = con)

    # return the file name
    file
  } else {
    HTML(paste(lines, collapse = "\n"))
  }
}

read_json <- function(file) {
  json <- readChar(file, nchars = file.info(file)$size, useBytes = TRUE)
  Encoding(json) <- "UTF-8"
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

extract_embedded_json <- function(file, id) {

  # open connection to file
  con <- file(file, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  # loop through the lines in the file
  begin_json <- paste0('<script type="text/json" id="', id, '">')
  end_json <- "</script>"
  in_json <- FALSE
  json_lines <- character()
  completed <- FALSE
  while (!completed) {

    # read next 100 lines
    lines <- readLines(con, n = 100, encoding = "UTF-8")
    lines <- iconv(lines, from = "", to = "UTF-8")
    if (length(lines) == 0)
      break

    # iterate through lines
    for (line in lines) {
      if (in_json && grepl(end_json, line, fixed = TRUE)) {
        completed <- TRUE
        break
      } else if (grepl(begin_json, line)) {
        in_json <- TRUE
        next
      }
      if (in_json)
        json_lines <- c(json_lines, line)
    }
  }

  if (length(json_lines) > 0)
    unserialize_embedded_json(json_lines)
  else
    NULL
}

unserialize_embedded_json <- function(lines) {
  # unescape code, see https://github.com/rstudio/rmarkdown/issues/943
  json <- gsub("<\\u002f", "</", lines, fixed = TRUE, useBytes = TRUE)
  jsonlite::unserializeJSON(json)
}

discover_preview <- function(file) {

  # if file is as the top-level of a site then bail
  if (file.exists(file.path(dirname(file), "_site.yml")))
    return(NULL)

  # if the file doesn't exist then bail (could be b/c we are being rendered
  # in RSC with an intermediates_dir)
  if (!file.exists(file))
    return(NULL)

  # open connection to file
  con <- file(file, open = "r", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  # loop through the lines in the file looking for images
  image_line <- NULL
  completed <- FALSE
  while (!completed) {

    # read next 500 lines
    lines <- readLines(con, n = 500)
    if (length(lines) == 0)
      break

    # look for a knitr image line
    image_line_indexes <- grep("^\\s*(?:<p>)?<img src=.*width=", lines)
    for (line_index in image_line_indexes) {

      # index line
      line <- lines[[line_index]]

      # record image_line if we don't already have one (this will result in
      # using the first image in the file if there is no data-distill-preview)
      if (is.null(image_line))
        image_line <- line

      # if it's marked with data-distill-preview we are done
      if (grepl('data-distill-preview=', line, fixed = TRUE)) {
        image_line <- line
        completed <- TRUE
        break
      }

    }
  }

  # if we have an image_line then use that
  if (!is.null(image_line)) {

    # extract img_src
    matches <- regmatches(image_line,  regexec('^\\s*(?:<p>)?<img src="([^"]+)"', image_line))
    img_src <- matches[[1]][[2]]

    # if it's a url then use it
    if (is_url(img_src)) {
      img_src
    }

    # if we are in a collection then we copy it to the collection root
    else if (startsWith(img_src, "data:image/")) {
      preview <- "distill-preview.png"
      preview_path <- file.path(dirname(file), preview)
      img_base64 <- sub("^data:image/.*,", "", img_src)
      img_bytes <- base64enc::base64decode(img_base64)
      writeBin(img_bytes, preview_path)
      preview
    }

    # otherwise in-place referece to files that exist
    else if (file.exists(file.path(dirname(file), img_src))) {
      img_src
    }

    # otherwise NULL
    else {
      NULL
    }

  } else {
    NULL
  }

}

merge_metadata <- function(site_config, collection_config, metadata, fields) {

  mergeable <- function(config) {
    if (!is.null(config) && !is.null(names(config))) {
      config <- config[fields]
      config[!is.na(names(config))]
    } else {
      NULL
    }
  }

  # merge collection level config into site config
  base_config <- merge_lists(mergeable(site_config), mergeable(collection_config))

  # merge article level metadata
  merge_lists(base_config, metadata)

}

authors_with_first_and_last_names <- function(authors) {
  lapply(authors, function(author) {
    if (is.null(author$name)) {
      author$name <- trimws(paste(not_null(author$first_name),
                                  not_null(author$last_name)))
    } else {
      names <- strsplit(author$name, '\\s+')[[1]]
      author$first_name <- paste(utils::head(names, -1), collapse = " ")
      author$last_name <- utils::tail(names, 1)
    }
    author
  })
}

bibtex_authors <- function(metadata_author) {
  paste(collapse = " and ", sapply(metadata_author, function(author) {
    paste0(author$last_name, ', ', author$first_name)
  }))
}

creative_commons_url <- function(metadata_creative_commons) {
  if (is.null(metadata_creative_commons)) return(NULL)
  if (metadata_creative_commons == "CC0") {
    "https://creativecommons.org/publicdomain/zero/1.0/"
  } else {
    sprintf("https://creativecommons.org/licenses/%s/4.0/",
            tolower(sub("^CC ", "", metadata_creative_commons))
    )
  }
}

# provide qualified title if specified in site and different from title
qualified_title <- function(site_config, metadata) {
  if (!is.null(site_config$title) && !identical(site_config$title, metadata$title)) {
    sprintf("%s: %s", site_config$title, metadata$title)
  } else {
    metadata$title
  }
}


