

# check for shiny classic
is_shiny_classic <- function(runtime) {
  identical(runtime, "shiny")
}

# wrapper over normalizePath that preserves NULLs and applies pandoc-friendly defaults
normalize_path <- function(path,
                           winslash = "/",
                           mustWork = NA) {

  if (!is.null(path))
    normalizePath(path, winslash = winslash, mustWork = mustWork)
}


not_null <- function(x, default="") {
  if (is.null(x))
    default
  else
    x
}

block_class = function(x){
  if (length(x) == 0) return()
  classes = unlist(strsplit(x, '\\s+'))
  .classes = paste0('.', classes, collapse = ' ')
  paste0('{', .classes, '}')
}

with_tz <- function(x, tzone = "") {
  as.POSIXct(as.POSIXlt(x, tz = tzone))
}

parse_date <- function(date) {
  if (!is.null(date)) {
    parsed_date <- lubridate::mdy(date, tz = Sys.timezone(), quiet = TRUE)
    if (lubridate::is.POSIXct(parsed_date))
      date <- parsed_date
  }
  date
}

date_as_iso_8601 <- function(date, date_only = FALSE) {
  if (date_only)
    format.Date(date, "%Y-%m-%d")
  else {
    date_text <- format.Date(date, "%Y-%m-%dT00:00:00.000%z")
    date_text <- sub("(\\d{2})(\\d{2})$", "\\1:\\2", date_text)
    date_text
  }
}

is_file_type <- function(file, type) {
  identical(tolower(tools::file_ext(file)), type)
}

dir_exists <- function(x) {
  utils::file_test('-d', x)
}

file_with_ext <- function(file, ext) {
  paste(tools::file_path_sans_ext(file), ".", ext, sep = "")
}

normalize_base_url <- function(url) {
  sub("/+$", "", url)
}


input_as_dir <- function(input) {

  # ensure the input dir exists
  if (!file.exists(input)) {
    stop("The specified directory '", normalize_path(input, mustWork = FALSE),
         "' does not exist.", call. = FALSE)
  }

  # convert from file to directory if necessary
  if (!dir_exists(input))
    input <- dirname(input)

  # return it
  input
}

html_from_file <- function(file) {
  HTML(readChar(file, nchars = file.info(file)$size, useBytes = TRUE))
}

html_as_file <- function(html) {
  html_content <- renderTags(html, indent = FALSE)$html
  html_file <- tempfile(fileext = "html")
  writeLines(html_content, html_file, useBytes = TRUE)
  html_file
}

files_to_lines <- function(files) {
  if (length(files) > 0) {
    paste(collapse = "\n", sapply(files, function(file) {
      readChar(file, nchars = file.info(file)$size, useBytes = TRUE)
    }))
  } else {
    c()
  }
}

merge_output_options <- function(base_options,
                                 overlay_options) {

  # if either one of these is a character vector then normalize to a named list
  normalize_list <- function(target) {
    if (is.null(target)) {
      list()
    } else if (is.character(target)) {
      setNames(lapply(target, function(x) list()), target)
    } else {
      target[names(target) != "..."]  # remove symbols (...) from list
    }
  }

  merge_lists(normalize_list(base_options), normalize_list(overlay_options))
}

merge_lists <- function(base_list, overlay_list, recursive = TRUE) {
  if (length(base_list) == 0)
    overlay_list
  else if (length(overlay_list) == 0)
    base_list
  else {
    merged_list <- base_list
    for (name in names(overlay_list)) {
      base <- base_list[[name]]
      overlay <- overlay_list[[name]]
      if (is.list(base) && is.list(overlay) && recursive)
        merged_list[[name]] <- merge_lists(base, overlay)
      else {
        merged_list[[name]] <- NULL
        merged_list <- append(merged_list,
                              overlay_list[which(names(overlay_list) %in% name)])
      }
    }
    merged_list
  }
}

is_osx <- function() {
  Sys.info()["sysname"] == "Darwin"
}

# function for resolving resources
radix_resource <- function(name) {
  system.file("rmarkdown/templates/radix_article/resources", name,
              package = "radix")
}

knitr_files_dir <- function(file) {
  paste(tools::file_path_sans_ext(file), "_files", sep = "")
}


knitr_cache_dir <- function(file, pandoc_to) {
  paste(tools::file_path_sans_ext(file), "_cache/", pandoc_to, "/", sep = "")
}


