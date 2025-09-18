#' Internal function to fetch RPPI data
#'
#' Fetches all Brazilian residential property price indices with hierarchical
#' access supporting individual indices (FipeZap, IVGR, IGMI, IQA, IVAR, SECOVI-SP)
#' and aggregations (sales, rent, all).
#'
#' @param table Character. Specific table/index to fetch. Can be:
#'   - Individual indices: "fipezap", "ivgr", "igmi", "iqa", "ivar", "secovi_sp"
#'   - Aggregations: "sales", "rent", "all"
#'   - Default: "fipezap"
#' @param cached Logical. Use cache if available
#' @param stack Logical. If TRUE, return single tibble with source column
#' @param quiet Logical. Suppress progress messages
#' @param max_retries Integer. Maximum retry attempts
#' @param ... Additional parameters
#'
#' @return Dataset as tibble or list depending on table parameter
#' @keywords internal
fetch_rppi <- function(table = "fipezap", cached = FALSE, stack = FALSE,
                       quiet = FALSE, max_retries = 3L, ...) {

  # Validate inputs ----
  valid_individual <- c("fipezap", "ivgr", "igmi", "iqa", "ivar", "secovi_sp")
  valid_aggregations <- c("sales", "rent", "all")
  valid_tables <- c(valid_individual, valid_aggregations)

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
      "i" = "Valid individual indices: {.val {valid_individual}}",
      "i" = "Valid aggregations: {.val {valid_aggregations}}"
    ))
  }

  # Handle aggregations ----
  if (table %in% valid_aggregations) {
    return(fetch_rppi_aggregation(table, cached, stack, quiet, max_retries, ...))
  }

  # Handle individual indices ----
  switch(table,
    "fipezap" = fetch_rppi_fipezap(cached = cached, quiet = quiet, max_retries = max_retries, ...),
    "ivgr" = fetch_rppi_ivgr(cached = cached, quiet = quiet, max_retries = max_retries, ...),
    "igmi" = fetch_rppi_igmi(cached = cached, quiet = quiet, max_retries = max_retries, ...),
    "iqa" = fetch_rppi_iqa(cached = cached, quiet = quiet, max_retries = max_retries, ...),
    "ivar" = fetch_rppi_ivar(cached = cached, quiet = quiet, max_retries = max_retries, ...),
    "secovi_sp" = fetch_rppi_secovi(cached = cached, quiet = quiet, max_retries = max_retries, ...)
  )
}

#' Internal function to fetch RPPI aggregations
#'
#' @keywords internal
fetch_rppi_aggregation <- function(table, cached, stack, quiet, max_retries, ...) {

  # Define aggregation mappings
  aggregations <- list(
    sales = c("fipezap", "ivgr", "igmi", "secovi_sp"),
    rent = c("iqa", "ivar", "secovi_sp"),
    all = c("fipezap", "ivgr", "igmi", "iqa", "ivar", "secovi_sp")
  )

  indices_to_fetch <- aggregations[[table]]

  if (!quiet) {
    cli::cli_inform("Fetching {table} RPPI aggregation ({length(indices_to_fetch)} indices)...")
  }

  # Fetch all required indices
  results <- list()
  for (idx in indices_to_fetch) {
    if (!quiet) {
      cli::cli_inform("Fetching {idx} index...")
    }

    results[[idx]] <- fetch_rppi(
      table = idx,
      cached = cached,
      stack = FALSE,
      quiet = quiet,
      max_retries = max_retries,
      ...
    )
  }

  # Handle stacking
  if (stack) {
    if (!quiet) {
      cli::cli_inform("Stacking {length(results)} indices into single dataset...")
    }

    result <- dplyr::bind_rows(results, .id = "source")

    # Add metadata
    attr(result, "source") <- "aggregated"
    attr(result, "download_time") <- Sys.time()
    attr(result, "download_info") <- list(
      aggregation = table,
      indices = indices_to_fetch,
      total_records = nrow(result)
    )

    return(result)
  }

  # Return as list
  attr(results, "source") <- "aggregated"
  attr(results, "download_time") <- Sys.time()
  attr(results, "download_info") <- list(
    aggregation = table,
    indices = indices_to_fetch
  )

  return(results)
}

#' Internal function to fetch FipeZap RPPI data
#'
#' @keywords internal
fetch_rppi_fipezap <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  # Handle cached data
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading FipeZap RPPI data from cache...")
    }

    tryCatch({
      df <- import_cached("rppi_fipe")

      if (!quiet) {
        cli::cli_inform("Successfully loaded {nrow(df)} FipeZap RPPI records from cache")
      }

      # Add metadata
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      attr(df, "download_info") <- list(
        index = "fipezap",
        source = "cache"
      )

      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn(c(
          "Failed to load cached data: {e$message}",
          "i" = "Falling back to fresh download"
        ))
      }
    })
  }

  # Fresh download
  if (!quiet) {
    cli::cli_inform("Downloading FipeZap RPPI data from Excel file...")
  }

  # Download Excel file with retry logic
  temp_path <- download_fipezap_excel(quiet = quiet, max_retries = max_retries)

  if (!quiet) {
    cli::cli_inform("Processing FipeZap Excel sheets...")
  }

  # Get all unique sheet names
  sheet_names <- readxl::excel_sheets(temp_path)
  # Remove summary sheets
  sheet_names <- sheet_names[!stringr::str_detect(sheet_names, "(Resumo)|(Aux)")]
  # Use sheets as city names
  city_names <- stringr::str_to_title(sheet_names)

  if (!quiet) {
    cli::cli_inform("Found {length(sheet_names)} city sheet{?s} to process")
  }

  # Import all data
  import_fipezap <- function(x) {
    # Get import range
    range <- get_range(path = temp_path, sheet = x)

    # Ad-hoc fix for get_range
    if (!stringr::str_detect(range, "BD")) {
      range <- paste0(range, ":BD", extract_numeric(range))
    }

    # Import and process sheet
    df <- readxl::read_excel(
      path = temp_path,
      sheet = x,
      range = range,
      col_names = FALSE
    )

    # Clean and process the data
    clean_fipezap_sheet(df, city_name = stringr::str_to_title(x))
  }

  # Process all sheets
  if (!quiet) {
    cli::cli_progress_bar(
      name = "Processing sheets",
      total = length(sheet_names),
      format = "{cli::pb_name} {cli::pb_current}/{cli::pb_total} [{cli::pb_bar}] {cli::pb_percent}"
    )
  }

  all_data <- list()
  for (i in seq_along(sheet_names)) {
    sheet <- sheet_names[i]

    if (!quiet) {
      cli::cli_progress_update()
    }

    tryCatch({
      all_data[[sheet]] <- import_fipezap(sheet)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Failed to process sheet '{sheet}': {e$message}")
      }
    })
  }

  if (!quiet) {
    cli::cli_progress_done()
  }

  # Combine all data
  result <- dplyr::bind_rows(all_data)

  # Add metadata
  attr(result, "source") <- "web"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    index = "fipezap",
    cities_processed = length(all_data),
    total_records = nrow(result),
    retry_attempts = 0,
    source = "fipe"
  )

  # Clean up temporary file
  if (file.exists(temp_path)) {
    file.remove(temp_path)
  }

  return(result)
}

#' Internal function to fetch IVGR RPPI data
#'
#' @keywords internal
fetch_rppi_ivgr <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading IVGR data from cache...")
    }

    tryCatch({
      df <- import_cached("rppi_ivgr")
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Cache failed, falling back to fresh download")
      }
    })
  }

  # Fresh download - implement IVGR specific logic here
  if (!quiet) {
    cli::cli_inform("Downloading IVGR data...")
  }

  # Placeholder for actual IVGR implementation
  cli::cli_abort("IVGR fresh download not yet implemented")
}

#' Internal function to fetch IGMI RPPI data
#'
#' @keywords internal
fetch_rppi_igmi <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading IGMI data from cache...")
    }

    tryCatch({
      df <- import_cached("rppi_igmi")
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Cache failed, falling back to fresh download")
      }
    })
  }

  # Fresh download - implement IGMI specific logic here
  if (!quiet) {
    cli::cli_inform("Downloading IGMI data...")
  }

  # Placeholder for actual IGMI implementation
  cli::cli_abort("IGMI fresh download not yet implemented")
}

#' Internal function to fetch IQA RPPI data
#'
#' @keywords internal
fetch_rppi_iqa <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading IQA data from cache...")
    }

    tryCatch({
      df <- import_cached("rppi_iqa")
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Cache failed, falling back to fresh download")
      }
    })
  }

  # Fresh download - implement IQA specific logic here
  if (!quiet) {
    cli::cli_inform("Downloading IQA data...")
  }

  # Placeholder for actual IQA implementation
  cli::cli_abort("IQA fresh download not yet implemented")
}

#' Internal function to fetch IVAR RPPI data
#'
#' @keywords internal
fetch_rppi_ivar <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading IVAR data from cache...")
    }

    tryCatch({
      df <- import_cached("rppi_ivar")
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Cache failed, falling back to fresh download")
      }
    })
  }

  # Fresh download - implement IVAR specific logic here
  if (!quiet) {
    cli::cli_inform("Downloading IVAR data...")
  }

  # Placeholder for actual IVAR implementation
  cli::cli_abort("IVAR fresh download not yet implemented")
}

#' Internal function to fetch SECOVI-SP RPPI data
#'
#' @keywords internal
fetch_rppi_secovi <- function(cached = FALSE, quiet = FALSE, max_retries = 3L, ...) {

  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading SECOVI-SP data from cache...")
    }

    tryCatch({
      df <- import_cached("secovi_sp")
      attr(df, "source") <- "cache"
      attr(df, "download_time") <- Sys.time()
      return(df)
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Cache failed, falling back to fresh download")
      }
    })
  }

  # Fresh download - use existing get_secovi function
  if (!quiet) {
    cli::cli_inform("Downloading SECOVI-SP data...")
  }

  # Call existing function for now - this will be cleaned up later
  result <- get_secovi(
    table = "all",
    cached = FALSE,
    quiet = quiet,
    max_retries = max_retries
  )

  return(result)
}

# Helper functions for FipeZap processing ----

#' Download FipeZap Excel file
#' @keywords internal
download_fipezap_excel <- function(quiet = FALSE, max_retries = 3L) {

  url <- "https://downloads.fipe.org.br/indices/fipezap/fipezap-serieshistoricas.xlsx"
  temp_path <- tempfile(fileext = ".xlsx")

  attempt <- 0
  while (attempt <= max_retries) {
    attempt <- attempt + 1

    tryCatch({
      if (!quiet) {
        cli::cli_inform("Attempting download (attempt {attempt}/{max_retries + 1})...")
      }

      httr::GET(
        url,
        httr::write_disk(temp_path, overwrite = TRUE),
        httr::timeout(60),
        httr::user_agent("realestatebr R package - research use")
      )

      if (file.exists(temp_path) && file.size(temp_path) > 0) {
        if (!quiet) {
          cli::cli_inform("Download successful")
        }
        return(temp_path)
      }

    }, error = function(e) {
      if (attempt > max_retries) {
        cli::cli_abort("Failed to download FipeZap Excel file after {max_retries + 1} attempts: {e$message}")
      }

      if (!quiet) {
        cli::cli_warn("Download attempt {attempt} failed: {e$message}")
        cli::cli_inform("Retrying in {attempt} seconds...")
      }

      Sys.sleep(attempt)
    })
  }
}

#' Clean FipeZap sheet data
#' @keywords internal
clean_fipezap_sheet <- function(df, city_name) {
  # This is a placeholder for the actual cleaning logic
  # The real implementation would process the FipeZap Excel format

  # Return empty tibble for now - real implementation needed
  tibble::tibble(
    date = as.Date(character()),
    name_muni = character(),
    market = character(),
    rent_sale = character(),
    variable = character(),
    rooms = character(),
    value = numeric()
  )
}

#' Extract numeric from range string
#' @keywords internal
extract_numeric <- function(range_str) {
  # Extract the numeric part from Excel range
  nums <- stringr::str_extract_all(range_str, "\\d+")[[1]]
  if (length(nums) > 0) nums[length(nums)] else "100"
}

#' Get Excel range for sheet
#' @keywords internal
get_range <- function(path, sheet) {
  # This is a placeholder for the actual range detection logic
  # The real implementation would detect the data range in each sheet
  "A1:Z100"
}