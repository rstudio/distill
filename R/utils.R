

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

is_osx <- function() {
  Sys.info()["sysname"] == "Darwin"
}

# detect if we are running in a Knit child process (i.e. destined
# for the internal R Markdown preview window)
validate_rstudio_version <- function() {

  # get the current rstudio version and mode (desktop vs. server)
  rstudio_version <- function() {

    # Running at the RStudio console
    if (rstudioapi::isAvailable()) {

      rstudioapi::versionInfo()

      # Running in a child process
    } else if (!is.na(Sys.getenv("RSTUDIO", unset = NA))) {

      # detect desktop vs. server using server-only environment variable
      mode <- ifelse(is.na(Sys.getenv("RSTUDIO_HTTP_REFERER", unset = NA)),
                     "desktop", "server")

      # detect version using Rmd new env var added in 1.2.638
      version <- Sys.getenv("RSTUDIO_VERSION", unset = "1.1")

      # return version info
      list(
        mode = mode,
        version = version
      )

      # Not running in RStudio
    } else {
      NULL
    }
  }

  # if we are running under rstudio then check whether this version
  # can render radix articles (since they use webcomponents polyfill)
  rstudio <- rstudio_version()
  if (!is.null(rstudio)) {

    # check for desktop mode on windows and linux (other modes are fine)
    if (!is_osx() && (rstudio$mode == "desktop")) {

      if (rstudio$version < "1.2.637")
        stop("Radix articles cannot be previewed in this version of RStudio.\n",
             "Please update to version 1.2.637 or higher at:\n",
             "https://www.rstudio.com/rstudio/download/preview/\n",
             call. = FALSE)
    }
  }
}


