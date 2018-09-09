
# detect if we are running in a Knit child process (i.e. destined
# for the internal R Markdown preview window)
validate_rstudio_version <- function() {

  # don't validate when running under TESTTHAT
  if (!is.na(Sys.getenv("TESTTHAT", unset = NA)))
    return()
  
  # if we are running under rstudio then check whether this version
  # can render radix articles (since they use webcomponents polyfill)
  rstudio <- rstudio_version()
  if (!is.null(rstudio)) {

    # check for desktop mode on windows and linux (other modes are fine)
    if (!is_osx() && (rstudio$mode == "desktop")) {

      if (rstudio$version < "1.2.718")
        stop("Radix articles cannot be previewed in this version of RStudio.\n",
             "Please update to version 1.2.718 or higher at ",
             "https://www.rstudio.com/products/rstudio/download/preview/\n",
             call. = FALSE)
    }
  }
}

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

have_rstudio_project_api <- function() {
  rstudioapi::isAvailable("1.1.287")
}
