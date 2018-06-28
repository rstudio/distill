
# From whoami package (didn't want the httr dependency b/c this makes
# the package difficult to install for beginners on Linux due to
# libcurl-dev requirement)

fullname <- function(fallback = NULL) {
  if (Sys.info()["sysname"] == "Darwin") {
    user <- try({
      user <- system("id -P", intern = TRUE)
      user <- str_trim(user)
      user <- strsplit(user, ":")[[1]][8]
    }, silent = TRUE)
    if (ok(user)) return(user)

    user <- try({
      user <- system("osascript -e \"long user name of (system info)\"",
                     intern = TRUE)
      user <- str_trim(user)
    }, silent = TRUE)
    if (ok(user)) return(user)

  } else if (.Platform$OS.type == "windows") {
    user <- try(suppressWarnings({
      user <- system("git config --global user.name", intern = TRUE)
      user <- str_trim(user)
    }), silent = TRUE)
    if (ok(user)) return(user)

    user <- try({
      username <- username()
      user <- system(
        paste0("wmic useraccount where name=\"", username,
               "\" get fullname"),
        intern = TRUE
      )
      user <- sub("FullName", "", user)
      user <- str_trim(paste(user, collapse = ""))
    }, silent = TRUE)

    if (ok(user)) return(user)

  } else {
    user <- try({
      user <- system("getent passwd $(whoami)", intern = TRUE)
      user <- str_trim(user)
      user <- strsplit(user, ":")[[1]][5]
      user <- sub(",.*", "")
    }, silent = TRUE)
    if (ok(user)) return(user)

  }

  user <- try(suppressWarnings({
    user <- system("git config --global user.name", intern = TRUE)
    user <- str_trim(user)
  }), silent = TRUE)
  if (ok(user)) return(user)

  fallback_or_stop(fallback, "Cannot determine full name")
}


ok <- function(x) {
  !inherits(x, "try-error") &&
    !is.null(x) &&
    length(x) == 1 &&
    x != "" &&
    !is.na(x)
}

`%or%` <- function(l, r) {
  if (ok(l)) l else r
}

str_trim <- function(x) {
  gsub("\\s+$", "", gsub("^\\s+", "", x))
}

fallback_or_stop <- function(fallback, msg) {
  if (!is.null(fallback)) {
    fallback
  } else {
    stop(msg)
  }
}

