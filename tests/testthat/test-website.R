context("website")

source("utils.R")

test_that("websites can be created", {
  skip_if_pandoc_not_installed()
  expect_error({
    on.exit(unlink("testsite", recursive = TRUE), add = TRUE)
    create_website("testsite", "Test Site", edit = FALSE)
  }, NA)
})

