test_that("script and style are not included as `article_content`", {
  skip_on_cran()
  skip_if_not_pandoc()
  rmd <- local_rmd_file(c(
    "---", "title: test", "---",
    "Some content", "",
    "<script> console.log('test')</script>", "",
    "<style>h1 { color: red }</style>", ""
  ))
  html <- local_render(rmd, output_format = 'distill::distill_article')
  expect_identical(str_trim(article_contents(html)), "Some content")
})
