

# check for shiny classic
is_shiny_classic <- function(runtime) {
  identical(runtime, "shiny")
}

as_utf8 <- function(x) {
  if (is.null(x))
    NULL
  else if (Encoding(x) != "UTF-8")
    iconv(x, from = "", to = "UTF-8")
  else
    x
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

not_null_or_empty <- function(x, default="") {
  if (is.null(x) || length(x) == 0)
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

resolve_date <- function(article_dir, date) {

  # if the date is null then see if the input_file has a date embedded in it's prefix
  if (is.null(date)) {
    if (grepl("^\\d{4}-\\d\\d?-\\d\\d?-", article_dir))
      date <- paste(strsplit(article_dir, "-")[[1]][1:3], collapse = "-")
  }

  # parse date
  parse_date(date)
}

is_date <- function(x) {
  lubridate::is.Date(x) ||
  lubridate::is.POSIXct(x) ||
  lubridate::is.POSIXlt(x)
}

parse_date <- function(date) {
  if (!is.null(date)) {
    parsed_date <- lubridate::mdy(date, tz = safe_timezone(), quiet = TRUE)
    if (is.na(parsed_date))
      parsed_date <- lubridate::ymd(date, tz = safe_timezone(), quiet = TRUE)
    if (lubridate::is.POSIXct(parsed_date))
      date <- parsed_date
  }
  date
}

safe_timezone <- function() {
  tz <- Sys.timezone()
  ifelse(is.na(tz), "UTC", tz)
}

time_as_iso_8601 <- function(time) {
  time <- format.Date(time, "%Y-%m-%dT%H:%M:%S%z")
  fixup_iso_timezone(time)
}

date_as_iso_8601 <- function(date, date_only = FALSE) {
  if (date_only)
    format.Date(date, "%Y-%m-%d")
  else {
    date_text <- format.Date(date, "%Y-%m-%dT00:00:00.000%z")
    date_text <- fixup_iso_timezone(date_text)
    date_text
  }
}

fixup_author <- function(author) {
  if (is.null(author))
    NULL
  else if (!is.list(author))
    lapply(author, function(x) list(name = x))
  else
    author
}

fixup_iso_timezone <- function(time) {
  sub("(\\d{2})(\\d{2})$", "\\1:\\2", time)
}

date_today <- function() {
  format(Sys.Date(), format = "%m-%d-%Y")
}

date_as_rfc_2822 <- function(date) {
  date <- as.Date(date, tz = "UTC")
  with_locale(
    new = c("LC_TIME" = ifelse(is_windows(), "English", "en_US.UTF-8")),
    format(date, format = "%a, %d %b %Y %H:%M:%S %z", tz = "UTC")
  )
}

date_as_abbrev <- function(date) {
  date <- as.Date(date, tz = "UTC")
  year <- format(date, "%Y")
  months <- c('Jan.', 'Feb.', 'March', 'April', 'May', 'June',
              'July', 'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.')
  month <- months[[as.integer(format(date, "%m"))]]
  day <- as.integer(format(date, "%d"))

  sprintf("%s %d, %s", month, day, year)
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

file_with_meta_ext <- function(file, meta_ext, ext = tools::file_ext(file)) {
  paste(tools::file_path_sans_ext(file),
        ".", meta_ext, ".", ext, sep = "")
}

strip_trailing_slash <- function(url) {
  sub("/+$", "", url)
}

ensure_trailing_slash <- function(url) {
  if (!endsWith(url, "/"))
    url <- paste0(url, "/")
  url
}

url_path <- function(...) {
  args <- lapply(list(...), strip_trailing_slash)
  args$fsep <- "/"
  do.call(file.path, args)
}

is_url <- function(x) {
  grepl("^https?://", x) || grepl("^mailto\\:", x)
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
  contents <- readChar(file, nchars = file.info(file)$size, useBytes = TRUE)
  Encoding(contents) <- "UTF-8"
  HTML(contents)
}

html_file <- function(html) {
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
      stats::setNames(lapply(target, function(x) list()), target)
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

is_windows <- function() {
  .Platform$OS.type == "windows"
}

# function for resolving resources
distill_resource <- function(name) {
  system.file("rmarkdown/templates/distill_article/resources", name,
              package = "distill")
}

knitr_files_dir <- function(file) {
  paste(tools::file_path_sans_ext(file), "_files", sep = "")
}


knitr_cache_dir <- function(file, pandoc_to) {
  paste(tools::file_path_sans_ext(file), "_cache/", pandoc_to, "/", sep = "")
}


rendering_note <- function(...) {
  cat("NOTE:", paste(..., collapse = " "), "\n\n", file = stderr())
}

move_directory <- function(from_dir, to_dir) {

  # remove the existing dir if necessary
  if (dir_exists(to_dir))
    unlink(to_dir, recursive = TRUE)

  # create the parent of the to_dir
  if (!dir_exists(dirname(to_dir)))
    dir.create(dirname(to_dir), recursive = TRUE)

  # attempt to move the dir in one shot (if that fails then copy it)
  result <- tryCatch(file.rename(from_dir, to_dir),
                     error = function(e) FALSE)
  if (!result) {
    dir.create(to_dir, recursive = TRUE)
    file.copy(
      from = from_dir,
      to = dirname(to_dir),
      recursive = TRUE
    )
    file.rename(file.path(dirname(to_dir), basename(from_dir)), to_dir)
  }

}

download_file <- function(url, destfile, quiet = TRUE) {
  if (is_url(url))
    utils::download.file(url, destfile = destfile, mode = "wb", quiet = quiet, cacheOK = FALSE)
  else if (file.exists(url))
    file.copy(url, destfile, overwrite = TRUE)
  else
    stop("Specified file does not exist: ", url)
}

eval_metadata <- function(metadata) {
  metadata_yaml <- yaml::as.yaml(metadata)
  metadata_yaml <- knitr::knit(text = metadata_yaml)
  yaml::yaml.load(metadata_yaml)
}


with_locale <-function (new, code) {
  old <- set_locale(cats = new)
  on.exit(set_locale(old))
  force(code)
}

set_locale <- function (cats) {
  cats <- as_character(cats)
  if ("LC_ALL" %in% names(cats)) {
    stop("Setting LC_ALL category not implemented.", call. = FALSE)
  }
  old <- vapply(names(cats), Sys.getlocale, character(1))
  mapply(Sys.setlocale, names(cats), cats)
  invisible(old)
}

as_character <- function (x) {
  nms <- names(x)
  res <- as.character(x)
  names(res) <- nms
  res
}




