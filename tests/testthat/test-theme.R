test_that("create_theme works", {
  withr::with_tempdir({
    expect_snapshot_output(create_theme("my-style"))
    expect_true(file.exists("my-style.css"))
  })
})
