test_that("date_as_rfc_2822", {
  expect_equal(date_as_rfc_2822("2023-02-24"), "Fri, 24 Feb 2023 00:00:00 +0000")
})

