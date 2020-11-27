
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
  bullet <- crayon::green(cli::symbol$tick)
  circle <- crayon::red(cli::symbol$record)
  cli::cat_line(paste(bullet, "Created CSS file at theme.css"))
  cli::cat_line(paste(circle, "TODO: Amend it to suit your needs"))
  cli::cat_line(paste(circle, "TODO: Apply it to your site/article cf ?create_theme"))
}
