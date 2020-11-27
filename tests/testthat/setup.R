
skip_if_pandoc_not_installed <- function() {
  skip_if_not(rmarkdown::pandoc_available("2.0"), "pandoc >= 2.0 not available")
}

