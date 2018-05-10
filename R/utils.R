

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
  else
    format.Date(date, "%Y-%m-%dT00:00:00.000%z")
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


