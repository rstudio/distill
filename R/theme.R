
#' Create a Distill theme CSS file
#'
#' Create a theme CSS file and write it to the current working directory
#'
#' @param name Name of theme file (will be written as name.css)
#' @param edit Open an editor for the theme file
#'
#' @includeRmd man/rmd-fragments/apply-theme.Rmd
#'
#' @section More details:
#' For further details about theming refer to the
#' [online documentation](https://rstudio.github.io/distill/website.html#theming).
#'
#' @export
create_theme  <- function(name = "theme", edit = TRUE) {
  css <- file_with_ext(name, "css")
  if (!file.exists(css))
    file.copy(distill_resource("base-variables.css"), css)
  else
    message("WARNING: ", css, " already exists and was not overwritten.")
  if (edit && rstudioapi::isAvailable()) {
    rstudioapi::navigateToFile(css)
  }

  bullet <- "v"
  circle <- "o"

  cat(paste(bullet, "Created CSS file at", css), "\n")
  cat(paste(circle, "TODO: Customize it to suit your needs"), "\n")
  cat(
    paste0(circle, " ", "TODO: Add 'theme: ", css, "' to your site or article YAML", "\n"),
    "\n")
  cat("See docs at https://rstudio.github.io/distill/website.html#theming")
}
