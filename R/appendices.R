

appendices_after_body_html <- function(input_file, site_config, metadata) {

  # write appendixes
  updates_and_corrections <- appendix_updates_and_corrections(metadata)
  creative_commons <- appendix_creative_commons(metadata)
  citation <- appendix_citation(site_config, metadata)
  appendix <- tags$div(class = "appendix-bottom",
                       updates_and_corrections,
                       creative_commons,
                       citation)

  # write bibliography
  bibliography <- c()
  if (!is.null(metadata$bibliography)) {
    bibliography <- HTML(paste(c(
      '<script id="distill-bibliography" type="text/bibtex">',
      readLines(file.path(dirname(input_file), metadata$bibliography), warn = FALSE),
      '</script>'
    ), collapse = "\n"))
  }

  # wrap in placeholder
  placeholder_html("appendices", tagList(
    appendix,
    bibliography
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
        '<a rel="license" href="%s">%s 4.0</a>. %sThe figures that have been reused from ',
        'other sources don\'t fall under this license and can be ',
        'recognized by a note in their caption: "Figure from ...".'
      ),
      htmlEscape(metadata$license_url, TRUE),
      htmlEscape(metadata$creative_commons),
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

    short_citation <- function() {
      if (!is.null(metadata$journal$title)) {
        sprintf('%s, "%s", %s, %s',
                metadata$concatenated_authors,
                qualified_title(site_config, metadata),
                metadata$journal$title,
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
