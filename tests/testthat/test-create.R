test_that("blogs can be created", {

  skip_if_not_pandoc()

  tmpdir <- withr::local_tempdir()

  blog_path <- file.path(tmpdir, "testblog")

  expect_error({
    create_blog(blog_path, "Test Blog", edit = FALSE)
  }, NA)

  expect_error({
    withr::local_dir(blog_path)
    create_post("My Post", edit = FALSE)
  }, NA)

})

test_that("websites can be created", {
  skip_if_not_pandoc()
  expect_error({
    on.exit(unlink("testsite", recursive = TRUE), add = TRUE)
    create_website("testsite", "Test Site", edit = FALSE)
  }, NA)
})




