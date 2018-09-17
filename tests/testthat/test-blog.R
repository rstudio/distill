
context("blog")

source("utils.R")

test_that("blogs can be created", {

  skip_if_pandoc_not_installed()

  tmpdir <- tempfile()
  dir.create(tmpdir, recursive = TRUE)
  on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

  blog_path <- file.path(tmpdir, "testblog")

  expect_error({
    create_blog(blog_path, "Test Blog", edit = FALSE)
  }, NA)

  expect_error({
    oldwd <- setwd(blog_path)
    on.exit(setwd(oldwd), add = TRUE)
    create_post("My Post", edit = FALSE)
  }, NA)

})





