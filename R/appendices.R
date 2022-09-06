

appendices_after_body_html <- function(input_file, site_config, metadata) {

  # write appendixes
  references <- appendix_bibliography(metadata)
  updates_and_corrections <- appendix_updates_and_corrections(metadata)
  creative_commons <- appendix_creative_commons(metadata)
  citation <- appendix_citation(site_config, metadata)
  appendix <- tags$div(class = "appendix-bottom",
                       references,
                       updates_and_corrections,
                       creative_commons,
                       citation)

  # wrap in placeholder
  placeholder_html("appendices", tagList(
    appendix
  ))
}

appendices_after_body_file <- function(input_file, site_config, metadata) {
  html_file(appendices_after_body_html(input_file, site_config, metadata))
}

appendix_updates_and_corrections <- function(metadata) {

  if (!is.null(metadata$repository_url)) {

    updates_and_corrections <- list()
    if (!is.null(metadata$compare_updates_url)) {
      updates_and_corrections[[length(updates_and_corrections) + 1]] <-
        tags$span(
          tags$a(href = metadata$compare_updates_url, "View all changes"),
          " to this article since it was first published. "
        )
      title <- "Updates and Corrections"
    } else {
      title <- "Corrections"
    }

    issues_url <- metadata$repository_url
    if (grepl("github.com", issues_url, fixed = TRUE)) {
      issues_url <- sub("/$", "", issues_url)
      issues_url <- paste0(issues_url, "/issues/new")
    }
    updates_and_corrections[[length(updates_and_corrections) + 1]] <-
      HTML(sprintf(paste0(
        'If you see mistakes or want to suggest changes, please ',
        '<a href="%s">create an issue</a> on the source repository.'
      ), htmlEscape(issues_url, attribute = TRUE)))

    tagList(
      tags$h3(id = "updates-and-corrections", title),
      tags$p(
        updates_and_corrections
      )
    )
  } else {
    NULL
  }
}

appendix_bibliography <- function(metadata) {
  if (!is.null(metadata$bibliography) | !is.null(metadata$references)) {
    list(
      tags$h3(id = "references", "References"),
      tags$div(id = "references-listing")
    )
  } else {
    NULL
  }
}

appendix_creative_commons <- function(metadata) {

  if (!is.null(metadata$creative_commons)) {

    source_note <- if (!is.null(metadata$repository_url)) {
      sprintf(paste0('Source code is available at <a href="%s">%s</a>, ',
                     'unless otherwise noted. '),
              htmlEscape(metadata$repository_url, attribute = TRUE),
              htmlEscape(metadata$repository_url)
      )
    } else {
      ""
    }

    reuse_note <- sprintf(
      paste0(
        'Text and figures are licensed under Creative Commons Attribution ',
        '%s. %sThe figures that have been reused from ',
        'other sources don\'t fall under this license and can be ',
        'recognized by a note in their caption: "Figure from ...".'
      ),
      # <a rel="license" href="%s">%s 4.0</a>
      a(rel = "license",
        href = htmlEscape(metadata$license_url, TRUE),
        htmlEscape(paste(metadata$creative_commons, basename(metadata$license_url)))
      ),
      source_note
    )

    list(
      tags$h3(id = "reuse", "Reuse"),
      tags$p(HTML(reuse_note))
    )
  } else {
    NULL
  }
}

appendix_citation <- function(site_config, metadata) {

  if (is_citeable(metadata)) {


    # ToDo: it would be nicer if we could auto-generate short citation according to csl file user provides. `multiple-bibliographies.lua` (https://github.com/pandoc/lua-filters/tree/master/multiple-bibliographies) can be considered to avoid any conflict with main text references div.
    short_citation <- function() {
      if (!is.null(metadata$journal$title)) {
        sprintf('%s, "%s", %s, %s',
                metadata$concatenated_authors,
                qualified_title(site_config, metadata),
                metadata$journal$title,
                metadata$published_year)
      } else if (!is.null(metadata$conference$title)) {
        sprintf('%s, "%s", %s, %s',
                metadata$concatenated_authors,
                qualified_title(site_config, metadata),
                metadata$conference$title,
                metadata$published_year)
      } else {
        sprintf('%s (%s, %s %d). %s. Retrieved from %s',
                metadata$concatenated_authors,
                metadata$published_year,
                metadata$published_month,
                metadata$published_day,
                qualified_title(site_config, metadata),
                metadata$citation_url)
      }
    }

    long_citation <- function() {
      if (!is.null(metadata$journal$title)) {

        suffix <- c()
        sep <- ifelse(!is.null(metadata$citation_url) && !is.null(metadata$doi), ",", "")
        if (!is.null(metadata$citation_url))
          suffix <- c(suffix, sprintf(',\n  note = {%s}', metadata$citation_url))
        if (!is.null(metadata$doi))
          suffix <- c(suffix, sprintf(',\n  doi = {%s}', metadata$doi))
        if (!is.null(metadata$volume))
          suffix <- c(suffix, sprintf(',\n  volume = {%s}', metadata$volume))
        if (!is.null(metadata$issue))
          suffix <- c(suffix, sprintf(',\n  issue = {%s}', metadata$issue))
        if (!is.null(metadata$isbn))
          suffix <- c(suffix, sprintf(',\n  isbn = {%s}', metadata$isbn))
        if (!is.null(metadata$journal$issn))
          suffix <- c(suffix, sprintf(',\n  issn = {%s}', metadata$journal$issn))
        if (!is.null(metadata$journal$publisher))
          suffix <- c(suffix, sprintf(',\n  publisher = {%s}', metadata$journal$publisher))
        if (!is.null(metadata$journal$firstpage) || !is.null(metadata$journal$lastpage))
          suffix <- c(suffix, sprintf(',\n  pages = {%s}', paste0(c(metadata$journal$firstpage, metadata$journal$lastpage), collapse = "-")))
        suffix <- paste0(c(suffix, '\n}'), collapse = '')
        sprintf(paste('@article{%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  journal = {%s},',
                      '  year = {%s}%s',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                qualified_title(site_config, metadata),
                metadata$journal$title,
                metadata$published_year,
                suffix
        )
      } else if (!is.null(metadata$conference$title)) {

        suffix <- c()
        sep <- ifelse(!is.null(metadata$citation_url) && !is.null(metadata$doi), ",", "")
        if (!is.null(metadata$citation_url))
          suffix <- c(suffix, sprintf(',\n  note = {%s}', metadata$citation_url))
        if (!is.null(metadata$doi))
          suffix <- c(suffix, sprintf(',\n  doi = {%s}', metadata$doi))
        if (!is.null(metadata$volume))
          suffix <- c(suffix, sprintf(',\n  volume = {%s}', metadata$volume))
        if (!is.null(metadata$issue))
          suffix <- c(suffix, sprintf(',\n  issue = {%s}', metadata$issue))
        if (!is.null(metadata$isbn))
          suffix <- c(suffix, sprintf(',\n  isbn = {%s}', metadata$isbn))
        if (!is.null(metadata$conference$issn))
          suffix <- c(suffix, sprintf(',\n  issn = {%s}', metadata$conference$issn))
        if (!is.null(metadata$conference$publisher))
          suffix <- c(suffix, sprintf(',\n  publisher = {%s}', metadata$conference$publisher))
        if (!is.null(metadata$conference$firstpage) || !is.null(metadata$conference$lastpage))
          suffix <- c(suffix, sprintf(',\n  pages = {%s}', paste0(c(metadata$conference$firstpage, metadata$conference$lastpage), collapse = "-")))
        suffix <- paste0(c(suffix, '\n}'), collapse = '')
        sprintf(paste('@conference{%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  booktitle = {%s},',
                      '  year = {%s},',
                      '  month = {%s}%s',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                qualified_title(site_config, metadata),
                metadata$conference$title,
                metadata$published_year,
                metadata$published_month,
                suffix
        )
      } else if (!is.null(metadata$thesis$type)) {

        suffix <- c()
        sep <- ifelse(!is.null(metadata$citation_url) && !is.null(metadata$doi), ",", "")
        if (!is.null(metadata$citation_url))
          suffix <- c(suffix, sprintf(',\n  note = {%s}', metadata$citation_url))
        if (!is.null(metadata$doi))
          suffix <- c(suffix, sprintf(',\n  doi = {%s}', metadata$doi))
        if (!is.null(metadata$isbn))
          suffix <- c(suffix, sprintf(',\n  isbn = {%s}', metadata$isbn))
        if (!is.null(metadata$thesis$issn))
          suffix <- c(suffix, sprintf(',\n  issn = {%s}', metadata$thesis$issn))
        if (!is.null(metadata$thesis$publisher))
          suffix <- c(suffix, sprintf(',\n  publisher = {%s}', metadata$thesis$publisher))
        if (!is.null(metadata$thesis$firstpage) || !is.null(metadata$thesis$lastpage))
          suffix <- c(suffix, sprintf(',\n  pages = {%s}', paste0(c(metadata$thesis$firstpage, metadata$thesis$lastpage), collapse = "-")))
        if (tolower(metadata$thesis$type) %in% c("phd", "masters")) {
          thesis_entry <- sprintf(paste0('@', tolower(metadata$thesis$type), 'thesis{%s'), metadata$slug)
        } else {
          thesis_entry <- sprintf('@thesis{%s', metadata$slug)
          suffix <- c(suffix, sprintf(',\n  type = {%s}', metadata$thesis$type))
        }
        suffix <- paste0(c(suffix, '\n}'), collapse = '')

        sprintf(paste('%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  school = {%s},',
                      '  year = {%s},',
                      '  month = {%s}%s',
                      sep = '\n'),
                thesis_entry,
                metadata$bibtex_authors,
                qualified_title(site_config, metadata),
                metadata$author[[1]]$affiliation,
                metadata$published_year,
                metadata$published_month,
                suffix
        )
      } else if (length(metadata$technical_report) != 0) {

        suffix <- c()
        sep <- ifelse(!is.null(metadata$citation_url) && !is.null(metadata$doi), ",", "")
        if (!is.null(metadata$citation_url))
          suffix <- c(suffix, sprintf(',\n  note = {%s}', metadata$citation_url))
        if (!is.null(metadata$doi))
          suffix <- c(suffix, sprintf(',\n  doi = {%s}', metadata$doi))
        if (!is.null(metadata$isbn))
          suffix <- c(suffix, sprintf(',\n  isbn = {%s}', metadata$isbn))
        if (!is.null(metadata$technical_report$issn))
          suffix <- c(suffix, sprintf(',\n  issn = {%s}', metadata$technical_report$issn))
        if (!is.null(metadata$technical_report$publisher))
          suffix <- c(suffix, sprintf(',\n  publisher = {%s}', metadata$technical_report$publisher))
        if (!is.null(metadata$technical_report$firstpage) || !is.null(metadata$technical_report$lastpage))
          suffix <- c(suffix, sprintf(',\n  pages = {%s}', paste0(c(metadata$technical_report$firstpage, metadata$technical_report$lastpage), collapse = "-")))
        if (!is.null(metadata$technical_report$number))
          suffix <- c(suffix, sprintf(',\n  number = {%s}', metadata$technical_report$number))
        suffix <- paste0(c(suffix, '\n}'), collapse = '')
        sprintf(paste('@techreport{%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  institution = {%s},',
                      '  year = {%s},',
                      '  month = {%s}%s',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                qualified_title(site_config, metadata),
                metadata$author[[1]]$affiliation,
                metadata$published_year,
                metadata$published_month,
                suffix
        )
      } else {
        sprintf(paste('@misc{%s,',
                      '  author = {%s},',
                      '  title = {%s},',
                      '  url = {%s},',
                      '  year = {%s}',
                      '}',
                      sep = '\n'),
                metadata$slug,
                metadata$bibtex_authors,
                qualified_title(site_config, metadata),
                metadata$citation_url,
                metadata$published_year
        )
      }
    }

    list(
      tags$h3(id = "citation", "Citation"),
      tags$p("For attribution, please cite this work as"),
      tags$pre(class = "citation-appendix short", short_citation()),
      tags$p("BibTeX citation"),
      tags$pre(class = "citation-appendix long", long_citation())
    )

  } else {
    NULL
  }

}
