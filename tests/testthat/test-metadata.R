test_that("Correct licence URL is found", {
  expect_null(creative_commons_url(NULL))
  expect_equal(creative_commons_url("CC0"), "https://creativecommons.org/publicdomain/zero/1.0/")
  expect_equal(creative_commons_url("CC BY-NC-SA"), "https://creativecommons.org/licenses/by-nc-sa/4.0/")
})
