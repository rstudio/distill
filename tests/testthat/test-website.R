context("website")

test_that("websites can be created", {
  skip_on_cran()
  expect_error({
    create_website("testsite", "Test Site", edit = FALSE)
    unlink("testsite")
  }, NA)
})

test_that("blogs can be created", {
  skip_on_cran()
  expect_error({
    create_blog("testblog", "Test Blog", edit = FALSE)
    unlink("testblog")
  }, NA)
})
