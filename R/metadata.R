

transform_configuration <- function(site_config, metadata) {

  # transform site_config and metadata values
  site_config <- transform_site_config(site_config)
  metadata <- transform_metadata(site_config, metadata)

  # provide title-prefix  and qualified title if specified in site and different from title
  if (!is.null(site_config$title) && !identical(site_config$title, metadata$title)) {
    metadata$title_prefix <- site_config$title
    metadata$qualified_title <- sprintf("%s: %s", site_config$title, metadata$title)
  } else {
    metadata$qualified_title <- metadata$title
  }

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

transform_metadata <- function(site_config, metadata) {

  # validate title
  if (is.null(metadata$title))
    stop("You must provide a title for Radix articles", call. = FALSE)

  # allow site level metadata to propagate
  site_metadata <- c("repository_url", "compare_updates_url", "creative_commons",
                     "license_url", "base_url", "preview", "slug", "citation_url",
                     "journal", "twitter")
  for (name in site_metadata)
    metadata[[name]] <- merge_lists(site_config[[name]], metadata[[name]])

  # propagate citation_url to canonical_url
  if (!is.null(metadata[["citation_url"]]) && is.null(metadata[["canonical_url"]]))
    metadata$canonical_url <- metadata$citation_url

  # parse dates
  metadata$date <- parse_date(metadata$date)
  metadata$updated <- parse_date(metadata$updated)

  if (!is.null(metadata$date)) {

    # derived date fields (used for citations)
    rfc_date <- function(date) {
      format.POSIXct(date, "%a, %d %b %Y %H:%M:%OS %z")
    }

    metadata$published_year <- format(metadata$date, "%Y")
    months <- c('Jan.', 'Feb.', 'March', 'April', 'May', 'June',
                'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.')
    metadata$published_month <- months[[as.integer(format(metadata$date, "%m"))]]
    metadata$published_day <- as.integer(format(metadata$date, "%d"))
    metadata$published_month_padded <- format(metadata$date, "%m")
    metadata$published_day_padded <- format(metadata$date, "%d")
    metadata$published_date_rfc <- rfc_date(metadata$date)
    if (!is.null(metadata$updated))
      metadata$updated_date_rfc <- rfc_date(metadata$updated)
    metadata$published_iso_date_only <- date_as_iso_8601(metadata$date, date_only = TRUE)
  }

  # normalize journal (for citations)
  if (!is.null(metadata$journal)) {
    if (is.character(metadata$journal))
      metadata$journal <- list(title = metadata$journal)
  } else {
    metadata$journal <- list()
  }

  # resolve creative commons license
  if (!is.null(metadata$creative_commons)) {

    # validate
    valid_licenses <- c("CC BY", "CC BY-SA", "CC BY-ND", "CC BY-NC",
                        "CC BY-NC-SA", "CC BY-NC-ND")
    if (!metadata$creative_commons %in% valid_licenses) {
      stop("creative_commonds license must be one of ",
           paste(valid_licenses, collapse = ", "))
    }

    # compute license url
    if (is.null(metadata$license_url)) {
      metadata$license_url <-
        paste0(
          "https://creativecommons.org/licenses/",
          tolower(sub("^CC ", "", metadata$creative_commons)), "/4.0/"
        )
    }
  }

  # base_url (strip trailing slashes)
  if (!is.null(metadata$base_url))
    metadata$base_url <- sub("/+$", "", metadata$base_url)

  # preview image
  if (!is.null(metadata$preview)) {

    # validate that the file exists
    if (!file.exists(metadata$preview)) {
      stop("Specified preview file '", metadata$preview, "' does not exist",
           call. = FALSE)
    }

    # validate that we have a base_url
    if (is.null(metadata$base_url)) {
      stop("You must specify a base_url to resolve relative image paths against ",
           "when specifying a preview image ",
           "(Open Graph and Twitter preview images must use absolute URLs", call. = FALSE)
    }

    # if it's a png then determine it's dimensions
    if (is_file_type(metadata$preview, "png")) {
      png <- png::readPNG(metadata$preview)
      metadata$preview_width <- ncol(png)
      metadata$preview_height <- nrow(png)
    }

    # resolve preview url
    metadata$preview <- file.path(metadata$base_url, metadata$preview)
  }

  # authors
  if (!is.null(metadata$author)) {

    # compute first and last name
    metadata$author <- lapply(metadata$author, function(author) {
      names <- strsplit(author$name, '\\s+')[[1]]
      author$first_name <- paste(utils::head(names, -1))
      author$last_name <- utils::tail(names, 1)
      author
    })

    # compute concatenated authors
    metadata$concatenated_authors <-
      if (length(metadata$author) > 2)
        paste0(metadata$author[[1]]$last_name, ', et al.')
    else if (length(metadata$author) == 2)
      paste(metadata$author[[1]]$last_name, '&', metadata$author[[2]]$last_name)
    else if (length(metadata$author) == 1)
      metadata$author[[1]]$last_name

    # compute bibtex authors
    metadata$bibtex_authors <-
      paste(collapse = " and ", sapply(metadata$author, function(author) {
        paste0(author$last_name, ', ', author$first_name)
      }))

    # slug
    if (is.null(metadata$slug) && !is.null(metadata$date)) {
      metadata$slug <- paste0(tolower(metadata$author[[1]]$last_name),
                              metadata$published_year,
                              tolower(strsplit(metadata$title, ' ')[[1]][[1]]))
    }
  }

  # failsafe for slug
  if (is.null(metadata$slug))
    metadata$slug <- "Untitled"

  metadata
}


metadata_in_header <- function(site_config, metadata) {

  # title
  title <- list()
  if (!is.null(metadata$qualified_title))
    title <- tags$title(metadata$qualified_title)

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
  if (!is.null(metadata$license_url)) {
    links[[length(links) + 1]] <- tags$link(
      rel = "license",
      href = metadata$license_url
    )
  }
  if (!is.null(site_config$favicon)) {
    links[[length(links) + 1]] <- tags$link(
      rel = "icon",
      type = mime::guess_type(site_config$favicon),
      href = site_config$favicon
    )
  }


  # authors meta tags
  author_meta <- lapply(metadata$author, function(author) {
    if (!is.list(author) || is.null(author$name) || is.null(author$url))
      stop("author metadata must include name and url fields", call. = FALSE)
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
  meta_tags <- placeholder_html("meta_tags", meta_tags)
  meta_html <- as.character(meta_tags)
  meta_file <- tempfile(fileext = "html")
  writeLines(meta_html, meta_file)

  meta_file
}


open_graph_metadata <- function(site_config, metadata) {

  # core descriptors
  open_graph_meta <- list(
    HTML("<!--  https://developers.facebook.com/docs/sharing/webmasters#markup -->"),
    tags$meta(property = "og:title", content = metadata$qualified_title),
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
  add_open_graph_meta("og:image", metadata$preview)
  add_open_graph_meta("og:image:width", metadata$preview_width)
  add_open_graph_meta("og:image:height", metadata$preview_height)

  # locale
  locale <- if (!is.null(metadata$lang))
    metadata$lang
  else if (!is.null(site_config$lang))
    site_config$lang
  else
    "en_US"
  add_open_graph_meta("og:locale", locale)

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
  card_type <- if(!is.null(metadata$preview)) "summary_large_image" else "summary"
  add_twitter_card_meta("twitter:card", card_type)

  # title and description
  add_twitter_card_meta("twitter:title", metadata$qualified_title)
  add_twitter_card_meta("twitter:description", metadata$description)

  # cannonical url
  add_twitter_card_meta("twitter:url", metadata$canonical_url)

  # preview image
  add_twitter_card_meta("twitter:image", metadata$preview)
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
    tags$meta(name = "citation_title", content = metadata$qualified_title)
  )

  # helper to add properties
  add_meta <- function(property, content) {
    if (!is.null(content)) {
      google_scholar_meta[[length(google_scholar_meta)+1]] <<-
        tags$meta(name = property, content = content)
    }
  }

  add_meta("citation_fulltext_html_url", metadata$citation_url)
  add_meta("citation_volume", metadata$volume)
  add_meta("citation_issue", metadata$issue)
  add_meta("citation_doi", metadata$doi)
  journal <- metadata$journal
  journal_title <- if (!is.null(journal$full_title) )
    journal$full_title
  else
    journal$title
  add_meta("citation_journal_title", journal$title)
  add_meta("citation_journal_abbrev", journal$abbrev_title)
  add_meta("citation_issn", journal$issn)
  add_meta("citation_publisher", journal$publisher)
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

  # references
  if (!is.null(metadata$bibliography)) {
    references <- pandoc_citeproc_convert(metadata$bibliography)
    for (ref in references)
      add_meta("citation_reference", citation_reference(ref))
  }

  google_scholar_meta
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
  if (!is.null(ref$issued))
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
      authorURL = author$url,
      affiliation = not_null(author$affiliation, "&nbsp;"),
      affiliationURL = not_null(author$affiliation_url, "#")
    )
  })
  if (!is.null(metadata$date))
    front_matter$publishedDate <- date_as_iso_8601(metadata$date)
  if (!is.null(metadata$concatenated_authors) && !is.null(metadata$published_year)) {
    front_matter$citationText <- sprintf("%s, %s",
                                         metadata$concatenated_authors,
                                         metadata$published_year)
  }
  jsonlite::toJSON(front_matter, auto_unbox = TRUE)
}

front_matter_before_body <- function(site_config, metadata) {

  front_matter_script <- HTML(paste(c(
    '',
    '<script id="distill-front-matter" type="text/json">',
    front_matter_from_metadata(metadata),
    '</script>',
    '') ,collapse = "\n")
  )
  front_matter_html <- renderTags(front_matter_script, indent = FALSE)$html
  front_matter_file <- tempfile(fileext = "html")
  writeLines(front_matter_html, front_matter_file)

  front_matter_file

}

embedded_metadata <- function(metadata) {
  embedded_json(metadata, "radix-rmarkdown-metadata")
}

extract_embedded_metadata <- function(file) {
  extract_embedded_json(file, "radix-rmarkdown-metadata")
}

embedded_json <- function(x, id, file = tempfile(fileext = "html")) {

  # generate json
  json <- jsonlite::serializeJSON(x)
  lines <- c('',
             paste0('<script type="text/json" ', 'id="', id ,'">'),
             # escape json, see https://github.com/rstudio/rmarkdown/issues/943
             gsub("</", "<\\u002f", json, fixed = TRUE),
             '</script>')

  # append to the file (guaranteed to be UTF-8)
  con <- file(file, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines(lines, con = con)

  # return the file name
  file
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
  json <- gsub("<\\u002f", "</", lines, fixed = TRUE)
  jsonlite::unserializeJSON(json)
}



