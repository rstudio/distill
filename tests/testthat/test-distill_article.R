test_that("distill articles can be created", {
  skip_if_not_pandoc()
  expect_s3_class(distill_article(), "rmarkdown_output_format")
})

