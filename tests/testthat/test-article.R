context("article")

source("utils.R")

test_that("radix articles can be created", {
  skip_if_pandoc_not_installed()
  expect_s3_class(radix_article(), "rmarkdown_output_format")
})

