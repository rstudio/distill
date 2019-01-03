#!/usr/bin/env Rscript
library(git2r)
library(stringr)
library(readr)
path <- file.path(tempfile(pattern = "git2r-"), "template")
dir.create(path, recursive = TRUE)
repo <- clone("https://github.com/rstudio/template", branch = "radix", path)
system2("npm", args = c("--prefix", path, "install"))
system2("npm", args = c("--prefix", path, "run", "build"))

transform_for_radix <- function(script) {
  highlighting_pattern <- "(?<=\\.languages.clike=\\{)"

  # Expect `Prism.languages.clike` and `n.languages.clike`
  count_match <- str_count(script, highlighting_pattern)
  if (!identical(2L, num_matches <- sum(count_match)))
    stop(paste0(num_matches, " matches for pattern ", p, " found, but two expected."), call. = FALSE)

  line_to_modify <- which(count_match == 2L)

  # Add comment patterns, being explicit about keys
  comment_patterns <- c(
    "(?<=Prism\\.languages\\.clike=\\{comment:\\[)",
    "(?<=n\\.languages\\.clike=\\{comment:\\[)"
  )
  comment_pattern_to_insert <- "{pattern:/(^|[^\\])#.*/,lookbehind:!0},"

  for (p in comment_patterns) {
    splitted <- script[[line_to_modify]] %>%
      str_split(p) %>%
      unlist()
    script[[line_to_modify]] <- paste0(splitted[[1]], comment_pattern_to_insert, splitted[[2]])
  }

  # Replace function patterns
  function_patterns <- c(
    "(?<=Prism\\.languages\\.clike=\\{.{0,500},function:)(.+?)(?=,number)",
    "(?<=n\\.languages\\.clike=\\{.{0,500},function:)(.+?)(?=,number)"
  )
  function_pattern_replacement <- "/[a-z\\.0-9_]+(?=\\()/i"

  for (p in function_patterns) {
    script[[line_to_modify]] <- script[[line_to_modify]] %>%
      str_replace(p, function_pattern_replacement)
  }

  # Function wrapper
  c("function load_distill_framework() {", script, "}")
}

read_lines(file.path(path, "dist", "template.v2.js")) %>%
  transform_for_radix() %>%
  write_lines("inst/www/distill/template.v2.js")

unlink(path, recursive = TRUE)
