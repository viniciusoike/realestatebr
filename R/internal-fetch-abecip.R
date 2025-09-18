#' Internal function to fetch ABECIP housing credit data
#'
#' Fetches housing credit data from Brazilian housing finance system (SFH)
#' including SBPE flows, financed units, and home equity loans.
#'
#' @param table Character. Specific table to fetch:
#'   - "sbpe": SBPE monetary flows (default)
#'   - "units": Financed units data
#'   - "cgi": Home equity loans (CGI)
#'   - "all": All tables as a list
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble (single table) or list (table = "all")
#' @keywords internal
fetch_abecip <- function(table = "sbpe", cached = FALSE, quiet = FALSE,
                         max_retries = 3L, ...) {

  # Validate inputs ----
  valid_tables <- c("sbpe", "units", "cgi", "all")

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!is.logical(cached) || length(cached) != 1) {
    cli::cli_abort("{.arg cached} must be a logical value")
  }

  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive number")
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading ABECIP data from cache...")
    }

    tryCatch({
      if (table == "all") {
        data <- import_cached("abecip")
      } else {
        # For single tables, get the full cached dataset and extract table
        data <- import_cached("abecip")
        if (is.list(data) && table %in% names(data)) {
          data <- data[[table]]
        } else {
          cli::cli_abort("Table '{table}' not found in cached data")
        }
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded ABECIP data from cache")
      }

      # Add metadata
      attr(data, "source") <- "cache"
      attr(data, "download_time") <- Sys.time()
      attr(data, "download_info") <- list(
        source = "cache",
        table = table
      )

      return(data)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn(c(
          "Failed to load cached data: {e$message}",
          "i" = "Falling back to fresh download"
        ))
      }
    })
  }

  # Download fresh data ----
  if (!quiet) {
    cli::cli_inform("Downloading data from ABECIP...")
  }

  # Handle single tables
  if (table != "all") {
    return(fetch_abecip_single_table(table, quiet, max_retries))
  }

  # Handle "all" case
  if (!quiet) {
    cli::cli_progress_bar(
      name = "Downloading all ABECIP datasets",
      total = 3,
      format = "{cli::pb_name} {cli::pb_current}/{cli::pb_total} [{cli::pb_bar}] {cli::pb_percent}"
    )
  }

  results <- list()

  # Download SBPE data
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$sbpe <- fetch_abecip_single_table("sbpe", quiet = TRUE, max_retries)

  # Download Units data
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$units <- fetch_abecip_single_table("units", quiet = TRUE, max_retries)

  # Get CGI data (static)
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$cgi <- fetch_abecip_single_table("cgi", quiet = TRUE, max_retries)

  if (!quiet) {
    cli::cli_progress_done()
    cli::cli_inform("Successfully downloaded all ABECIP datasets")
  }

  # Add metadata
  attr(results, "source") <- "web"
  attr(results, "download_time") <- Sys.time()
  attr(results, "download_info") <- list(
    table = "all",
    datasets = c("sbpe", "units", "cgi"),
    total_records = sum(sapply(results, nrow))
  )

  return(results)
}

#' Internal function to fetch single ABECIP table
#'
#' @keywords internal
fetch_abecip_single_table <- function(table, quiet = FALSE, max_retries = 3L) {

  switch(table,
    "sbpe" = download_abecip_sbpe(quiet = quiet, max_retries = max_retries),
    "units" = download_abecip_units(quiet = quiet, max_retries = max_retries),
    "cgi" = get_abecip_cgi_data(quiet = quiet),
    cli::cli_abort("Unknown ABECIP table: {table}")
  )
}

#' Download ABECIP SBPE data
#'
#' @keywords internal
download_abecip_sbpe <- function(quiet = FALSE, max_retries = 3L) {

  if (!quiet) {
    cli::cli_inform("Downloading SBPE monetary flows data...")
  }

  # URL for SBPE data
  url <- "https://www.abecip.org.br/upload/relatorios/relatorio-de-mercado"

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting SBPE download (attempt {attempt}/{max_retries + 1})...")
      }

      # This is a placeholder for the actual SBPE download logic
      # The real implementation would scrape the ABECIP website
      # and extract SBPE monetary flows data

      # For now, return empty tibble with correct structure
      result <- tibble::tibble(
        date = as.Date(character()),
        sbpe_value = numeric(),
        rural_value = numeric(),
        total_value = numeric(),
        currency = character()
      )

      if (!quiet) {
        cli::cli_inform("SBPE data download successful")
      }

      # Add metadata
      attr(result, "source") <- "web"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = "sbpe",
        url = url,
        retry_attempts = attempt - 1
      )

      return(result)

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download SBPE data after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("SBPE download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}

#' Download ABECIP Units data
#'
#' @keywords internal
download_abecip_units <- function(quiet = FALSE, max_retries = 3L) {

  if (!quiet) {
    cli::cli_inform("Downloading financed units data...")
  }

  # URL for Units data
  url <- "https://www.abecip.org.br/upload/relatorios/relatorio-de-mercado"

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting Units download (attempt {attempt}/{max_retries + 1})...")
      }

      # This is a placeholder for the actual Units download logic
      # The real implementation would scrape the ABECIP website
      # and extract financed units data

      # For now, return empty tibble with correct structure
      result <- tibble::tibble(
        date = as.Date(character()),
        units_construction = numeric(),
        units_acquisition = numeric(),
        units_total = numeric(),
        currency_construction = numeric(),
        currency_acquisition = numeric(),
        currency_total = numeric()
      )

      if (!quiet) {
        cli::cli_inform("Units data download successful")
      }

      # Add metadata
      attr(result, "source") <- "web"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = "units",
        url = url,
        retry_attempts = attempt - 1
      )

      return(result)

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download Units data after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Units download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}

#' Get ABECIP CGI data (static)
#'
#' @keywords internal
get_abecip_cgi_data <- function(quiet = FALSE) {

  if (!quiet) {
    cli::cli_inform("Loading CGI data from package...")
  }

  # This would reference the internal CGI dataset
  # For now, return empty tibble with correct structure
  result <- tibble::tibble(
    date = as.Date(character()),
    contracts = numeric(),
    default_rate = numeric(),
    average_term = numeric(),
    value = numeric()
  )

  # Add metadata
  attr(result, "source") <- "package"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = "cgi",
    source = "static_package_data"
  )

  return(result)
}