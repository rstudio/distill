test_that("distill articles can be created", {
  skip_if_pandoc_not_installed()
  expect_s3_class(distill_article(), "rmarkdown_output_format")
})

