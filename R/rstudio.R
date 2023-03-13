
# detect if we are running in a Knit child process (i.e. destined
# for the internal R Markdown preview window)
validate_rstudio_version <- function() {

  # don't validate when running under TESTTHAT
  if (!is.na(Sys.getenv("TESTTHAT", unset = NA)))
    return()

  # if we are running under rstudio then check whether this version
  # can render distill articles (since they use webcomponents polyfill)
  rstudio <- rstudio_version()
  if (!is.null(rstudio)) {

    # check for desktop mode on windows and linux (other modes are fine)
    if (!is_osx() && (rstudio$mode == "desktop")) {

      if (package_version(rstudio$version) < package_version("1.2.718"))
        stop("Distill articles cannot be previewed in this version of RStudio.\n",
             "Please update to version 1.2.718 or higher at ",
             "https://posit.co/downloads/\n",
             call. = FALSE)
    }
  }
}

# get the current rstudio version and mode (desktop vs. server)
rstudio_version <- function() {

  # Running at the RStudio console
  if (rstudioapi::isAvailable()) {

    rstudioapi::versionInfo()[c("mode", "version")]

    # Running in a child process of RStudio (e.g render pane)
  } else if (is_rstudio()) {

    if (is_tty()) {
      # probably called using callr from within rstudio
      return(NULL)
    }

    # detect version using Rmd new env var added in 1.2.638
    # If not set
    version <- Sys.getenv("RSTUDIO_VERSION", unset = "1.1")

    # detect desktop vs. server using server-only environment variable
    mode <- ifelse(is.na(Sys.getenv("RSTUDIO_HTTP_REFERER", unset = NA)),
                   "desktop", "server")


    # Support new scheme when IDE report wrongly
    # https://github.com/rstudio/rstudio/pull/9796#issuecomment-931200543
    # TODO: remove when fixed in later release
    version <- gsub("(?:-(?:preview|daily))?[+](\\d+)(?:.pro\\d+)?", ".\\1", version)

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

have_rstudio_project_api <- function() {
  rstudioapi::isAvailable("1.1.287")
}


is_rstudio <- function() {
  Sys.getenv("RSTUDIO") == "1"
}

is_rstudio_console <- function() {
  .Platform$GUI == "RStudio"
}

# should be true when run inside a background process of the console
# e.g using callr (callr::r(\() isatty(stdin())))
is_tty <- function() {
  isatty(stdin())
}

