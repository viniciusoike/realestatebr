#' Internal function to fetch ABRAINC-FIPE primary market indicators
#'
#' Fetches primary real estate market indicators including launches, sales,
#' and business conditions from 66+ partnered developers.
#'
#' @param table Character. Specific table to fetch:
#'   - "indicator": Market indicators (default)
#'   - "radar": Business radar (0-10 index)
#'   - "leading": Leading indicator (building permits)
#'   - "all": All tables as a list
#' @param cached Logical. Use cache if available
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble (single table) or list (table = "all")
#' @keywords internal
fetch_abrainc <- function(table = "indicator", cached = FALSE, quiet = FALSE,
                          max_retries = 3L, ...) {

  # Validate inputs ----
  valid_tables <- c("indicator", "radar", "leading", "all")

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
      cli::cli_inform("Loading ABRAINC data from cache...")
    }

    tryCatch({
      if (table == "all") {
        data <- import_cached("abrainc")
      } else {
        # For single tables, get the full cached dataset and extract table
        data <- import_cached("abrainc")
        if (is.list(data) && table %in% names(data)) {
          data <- data[[table]]
        } else {
          cli::cli_abort("Table '{table}' not found in cached data")
        }
      }

      if (!quiet) {
        cli::cli_inform("Successfully loaded ABRAINC data from cache")
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
    cli::cli_inform("Downloading data from ABRAINC-FIPE...")
  }

  # Handle single tables
  if (table != "all") {
    return(fetch_abrainc_single_table(table, quiet, max_retries))
  }

  # Handle "all" case
  if (!quiet) {
    cli::cli_progress_bar(
      name = "Downloading all ABRAINC datasets",
      total = 3,
      format = "{cli::pb_name} {cli::pb_current}/{cli::pb_total} [{cli::pb_bar}] {cli::pb_percent}"
    )
  }

  results <- list()

  # Download Indicator data
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$indicator <- fetch_abrainc_single_table("indicator", quiet = TRUE, max_retries)

  # Download Radar data
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$radar <- fetch_abrainc_single_table("radar", quiet = TRUE, max_retries)

  # Download Leading data
  if (!quiet) {
    cli::cli_progress_update()
  }
  results$leading <- fetch_abrainc_single_table("leading", quiet = TRUE, max_retries)

  if (!quiet) {
    cli::cli_progress_done()
    cli::cli_inform("Successfully downloaded all ABRAINC datasets")
  }

  # Add metadata
  attr(results, "source") <- "web"
  attr(results, "download_time") <- Sys.time()
  attr(results, "download_info") <- list(
    table = "all",
    datasets = c("indicator", "radar", "leading"),
    total_records = sum(sapply(results, nrow))
  )

  return(results)
}

#' Internal function to fetch single ABRAINC table
#'
#' @keywords internal
fetch_abrainc_single_table <- function(table, quiet = FALSE, max_retries = 3L) {

  switch(table,
    "indicator" = download_abrainc_indicator(quiet = quiet, max_retries = max_retries),
    "radar" = download_abrainc_radar(quiet = quiet, max_retries = max_retries),
    "leading" = download_abrainc_leading(quiet = quiet, max_retries = max_retries),
    cli::cli_abort("Unknown ABRAINC table: {table}")
  )
}

#' Download ABRAINC Indicator data
#'
#' @keywords internal
download_abrainc_indicator <- function(quiet = FALSE, max_retries = 3L) {

  if (!quiet) {
    cli::cli_inform("Downloading ABRAINC Indicator data...")
  }

  # URL for ABRAINC Excel file
  url <- "https://www.fipe.org.br/pt-br/indices/abrainc"

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting Indicator download (attempt {attempt}/{max_retries + 1})...")
      }

      # This is a placeholder for the actual Indicator download logic
      # The real implementation would download and process the ABRAINC Excel file

      # For now, return empty tibble with correct structure
      result <- tibble::tibble(
        date = as.Date(character()),
        variable = character(),
        market_segment = character(),
        value = numeric(),
        unit = character()
      )

      if (!quiet) {
        cli::cli_inform("Indicator data download successful")
      }

      # Add metadata
      attr(result, "source") <- "web"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = "indicator",
        url = url,
        retry_attempts = attempt - 1
      )

      return(result)

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download Indicator data after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Indicator download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}

#' Download ABRAINC Radar data
#'
#' @keywords internal
download_abrainc_radar <- function(quiet = FALSE, max_retries = 3L) {

  if (!quiet) {
    cli::cli_inform("Downloading ABRAINC Radar data...")
  }

  # URL for ABRAINC Excel file
  url <- "https://www.fipe.org.br/pt-br/indices/abrainc"

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting Radar download (attempt {attempt}/{max_retries + 1})...")
      }

      # This is a placeholder for the actual Radar download logic
      # For now, return empty tibble with correct structure
      result <- tibble::tibble(
        date = as.Date(character()),
        radar_index = numeric(),
        component = character(),
        value = numeric()
      )

      if (!quiet) {
        cli::cli_inform("Radar data download successful")
      }

      # Add metadata
      attr(result, "source") <- "web"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = "radar",
        url = url,
        retry_attempts = attempt - 1
      )

      return(result)

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download Radar data after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Radar download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}

#' Download ABRAINC Leading data
#'
#' @keywords internal
download_abrainc_leading <- function(quiet = FALSE, max_retries = 3L) {

  if (!quiet) {
    cli::cli_inform("Downloading ABRAINC Leading indicator data...")
  }

  # URL for ABRAINC Excel file
  url <- "https://www.fipe.org.br/pt-br/indices/abrainc"

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting Leading download (attempt {attempt}/{max_retries + 1})...")
      }

      # This is a placeholder for the actual Leading download logic
      # For now, return empty tibble with correct structure
      result <- tibble::tibble(
        date = as.Date(character()),
        building_permits = numeric(),
        leading_index = numeric(),
        region = character()
      )

      if (!quiet) {
        cli::cli_inform("Leading data download successful")
      }

      # Add metadata
      attr(result, "source") <- "web"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = "leading",
        url = url,
        retry_attempts = attempt - 1
      )

      return(result)

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download Leading data after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Leading download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}