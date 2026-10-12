# Test suite for 0.4.0 internal function architecture
# This tests the new internal fetch functions and updated get_dataset() behavior

test_that("materialized datasets have internal_function fields", {
  registry <- load_dataset_registry()

  for (dataset_name in names(registry$datasets)) {
    dataset_info <- registry$datasets[[dataset_name]]

    if ((dataset_info$access_mode %||% "materialized") != "materialized") {
      next
    }

    expect_true(
      !is.null(dataset_info$internal_function) &&
        dataset_info$internal_function != "",
      info = paste("Dataset", dataset_name, "missing internal_function field")
    )
  }
})

test_that("get_dataset uses internal functions for fresh downloads", {
  skip_if_not_live()

  data <- get_dataset("abecip", source = "fresh", table = "sbpe")
  expect_s3_class(data, "data.frame")
  expect_gt(nrow(data), 0)
})

test_that("internal functions have consistent parameter interface", {
  required_params <- c("table", "quiet", "max_retries")

  internal_functions <- c(
    "get_rppi",
    "get_abecip_indicators",
    "get_abrainc_indicators",
    "get_bcb_realestate",
    "get_bcb_series",
    "get_secovi",
    "get_rppi_bis"
  )

  for (func_name in internal_functions) {
    if (
      exists(func_name, mode = "function", envir = asNamespace("realestatebr"))
    ) {
      func <- get(func_name, envir = asNamespace("realestatebr"))
      func_params <- names(formals(func))

      for (param in required_params) {
        expect_true(
          param %in% func_params,
          info = paste(func_name, "missing required parameter:", param)
        )
      }
    }
  }
})

test_that("RPPI hierarchical access works through internal functions", {
  skip_if_not_live()

  fipezap_data <- get_dataset("rppi", source = "fresh", table = "fipezap")
  sales_data <- get_dataset("rppi", source = "fresh", table = "sale")
  expect_s3_class(fipezap_data, "data.frame")
  expect_s3_class(sales_data, "data.frame")
  expect_gt(nrow(fipezap_data), 0)
  expect_gt(nrow(sales_data), 0)
})

test_that("dataset registry consolidated correctly", {
  registry <- load_dataset_registry()

  # rppi_indices should not exist anymore (consolidated into rppi)
  expect_false("rppi_indices" %in% names(registry$datasets))

  # rppi should have hierarchical structure
  rppi_info <- registry$datasets$rppi
  expect_true(!is.null(rppi_info$categories))
  expect_true("fipezap" %in% names(rppi_info$categories))
  expect_true("sale" %in% names(rppi_info$categories))
  expect_true("rent" %in% names(rppi_info$categories))
  expect_true("all" %in% names(rppi_info$categories))
})

test_that("internal functions handle errors gracefully", {
  # Test invalid table parameter using actual legacy functions
  expect_error(
    get_abecip_indicators(table = "invalid_table"),
    "Invalid table"
  )

  expect_error(
    get_abrainc_indicators(table = "invalid_table"),
    "Invalid table"
  )

  expect_error(
    get_rppi(table = "invalid_table"),
    "Invalid"
  )
})

test_that("internal functions validate input parameters", {
  expect_error(get_abecip_indicators(table = 123), "must be")
  expect_error(get_abecip_indicators(quiet = "no"), "logical")
})

test_that("internal functions return expected data structure", {
  skip_if_not_live()

  data <- get_dataset("abecip", table = "sbpe", source = "github")
  expect_true(!is.null(attr(data, "source")))
  expect_true(!is.null(attr(data, "download_time")))
  expect_true(!is.null(attr(data, "download_info")))
})

test_that("BCB datasets have distinct dataset_function entries", {
  registry <- load_dataset_registry()

  expect_equal(
    registry$datasets$bcb_realestate$dataset_function,
    "get_bcb_realestate"
  )
  expect_equal(
    registry$datasets$bcb_series$dataset_function,
    "get_bcb_series"
  )
})

test_that("all materialized datasets are accessible through get_dataset", {
  skip_if_not_live()

  registry <- load_dataset_registry()

  for (dataset_name in names(registry$datasets)) {
    dataset_info <- registry$datasets[[dataset_name]]
    if ((dataset_info$access_mode %||% "materialized") != "materialized") {
      next
    }

    data <- get_dataset(dataset_name, source = "github")
    expect_false(is.null(data), info = dataset_name)
  }
})

test_that("lazy-loaded data resolves without attaching the package", {
  skip_on_cran()
  skip_if_not_installed("callr")

  # Runs in a subprocess because testthat attaches the package, which masks
  # the bug: lazy-loaded data lives in the namespace's lazydata environment.
  # The subprocess loads the installed package, so run after R CMD INSTALL.
  codes <- callr::r(function() realestatebr:::resolve_bcb_hierarchy("core"))

  expect_gt(length(codes), 0)
  expect_false(anyNA(codes))
})
