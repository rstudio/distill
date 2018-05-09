

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
    parsed_date <- parsedate::parse_date(date)
    if (!is.na(parsed_date))
      date <- parsed_date
  }
  date
}

date_as_iso_8601 <- function(date) {
  parsedate::format_iso_8601(date)
}

is_file_type <- function(file, type) {
  identical(tolower(tools::file_ext(file)), type)
}

