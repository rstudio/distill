context("website")

test_that("websites can be created", {
  skip_on_cran()
  expect_error({
    on.exit(unlink("testsite", recursive = TRUE), add = TRUE)
    create_website("testsite", "Test Site", edit = FALSE)
  }, NA)
})

test_that("blogs can be created", {
  skip_on_cran()
  expect_error({
    on.exit(unlink("testblog", recursive = TRUE), add = TRUE)
    create_blog("testblog", "Test Blog", edit = FALSE)
  }, NA)
})
