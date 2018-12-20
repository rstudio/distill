#!/usr/bin/env Rscript
library(git2r)
library(stringr)
library(readr)
path <- file.path(tempfile(pattern = "git2r-"), "template")
dir.create(path, recursive = TRUE)
repo <- clone("https://github.com/rstudio/template", branch = "radix", path)
system2("npm", args = c("--prefix", path, "install"))
system2("npm", args = c("--prefix", path, "run", "build"))
read_lines(file.path(path, "dist", "template.v2.js")) %>%
  str_replace(fixed("/[a-z0-9_]+(?=\\()/i"), "/[a-z\\.0-9_]+(?=\\()/i") %>%
  str_replace(fixed("/`( ? : \\\\\\\\ | \\\\ ? [ ^ \\\\]) * ? `/"), "/`(?:\\\\\\\\|\\\\?[^\\\\])*?`/") %>%
  str_replace(fixed("/\\$\\([^)]+\\)|` [ ^ `]+` /,"), "/\\$\\([^)]+\\)|`[^`]+`/") %>%
  c("function load_distill_framework() {", ., "}") %>%
  write_lines("inst/www/distill/template.v2.js")
unlink(path, recursive = TRUE)
