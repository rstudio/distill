
#' Create a Distill theme CSS file
#'
#' Create a theme CSS file and write it to the current working directory
#'
#' @param name Name of theme file (will be written as name.css)
#' @param edit Open an editor for the theme file
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
}
