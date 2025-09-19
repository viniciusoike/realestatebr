#' Internal B3 Data Fetching Functions
#'
#' These functions provide the core infrastructure for fetching B3 stock market
#' data using the rb3 package instead of quantmod.
#'
#' @keywords internal
#' @name internal-b3
NULL

#' Fetch B3 Stock Data Using rb3
#'
#' Internal function that fetches stock data using rb3 infrastructure.
#' This replaces the quantmod-based approach with native B3 data access.
#'
#' @param symbols Character vector of stock symbols to fetch
#' @param start_date Date or character. Start date for data fetching
#' @param end_date Date or character. End date for data fetching
#' @param quiet Logical. If TRUE, suppresses progress messages
#' @param cache_dir Character. Directory for rb3 cache (optional)
#'
#' @return A tibble with stock data
#' @keywords internal
#' @importFrom rb3 fetch_marketdata cotahist_get indexes_historical_data_get
#' @importFrom bizdays bizseq
#' @importFrom dplyr filter select collect mutate left_join bind_rows
#' @importFrom lubridate as_date year
#' @importFrom stringr str_remove
#' @importFrom cli cli_inform cli_warn cli_abort
fetch_b3_stocks_rb3 <- function(symbols = NULL, start_date = NULL, end_date = NULL, 
                                quiet = FALSE, cache_dir = NULL) {
  
  # Set up rb3 cache directory if provided
  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }
    options(rb3.cachedir = cache_dir)
  }
  
  # Default symbols if none provided
  if (is.null(symbols)) {
    # Get real estate companies symbols from b3_real_estate
    symbols <- b3_real_estate$symbol
    # Add relevant financial indices
    index_symbols <- c("^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX")
  } else {
    # Separate stock symbols from index symbols
    index_symbols <- symbols[grepl("^\\^|^[A-Z]{3}$|IFIX", symbols)]
    symbols <- symbols[!grepl("^\\^|^[A-Z]{3}$|IFIX", symbols)]
  }
  
  # Set default date range if not provided
  if (is.null(end_date)) {
    end_date <- Sys.Date()
  }
  if (is.null(start_date)) {
    start_date <- as.Date(end_date) - 365  # Default to 1 year
  }
  
  # Convert dates to Date objects
  start_date <- lubridate::as_date(start_date)
  end_date <- lubridate::as_date(end_date)
  
  stock_data <- NULL
  index_data <- NULL
  
  # Fetch stock data if we have stock symbols
  if (length(symbols) > 0) {
    if (!quiet) {
      cli::cli_inform("Fetching daily stock data for {length(symbols)} symbols...")
    }
    
    tryCatch({
      # Generate business days sequence for Brazil/B3
      date_seq <- bizdays::bizseq(start_date, end_date, "Brazil/B3")
      
      # Fetch market data (this downloads and caches data locally)
      rb3::fetch_marketdata(
        "b3-cotahist-daily",
        refdate = date_seq,
        throttle = TRUE
      )
      
      # Connect to local database
      eq <- rb3::cotahist_get("daily")
      
      # Clean symbols (remove .SA suffix if present)
      clean_symbols <- stringr::str_remove(symbols, "\\.SA$")
      
      # Extract data for our symbols
      stock_data <- eq |>
        dplyr::filter(
          symbol %in% clean_symbols,
          refdate >= start_date,
          refdate <= end_date
        ) |>
        dplyr::select(
          refdate, symbol, close, volume, trade_quantity, traded_contracts,
          high, low, open
        ) |>
        dplyr::collect() |>
        # Standardize column names to match legacy format
        dplyr::mutate(
          date = refdate,
          price_close = close,
          price_high = high,
          price_low = low,
          price_open = open,
          volume = volume
        ) |>
        dplyr::select(date, symbol, price_open, price_high, price_low, 
                     price_close, volume, trade_quantity, traded_contracts)
      
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Failed to fetch stock data: {e$message}")
      }
    })
  }
  
  # Fetch index data if we have index symbols
  if (length(index_symbols) > 0) {
    if (!quiet) {
      cli::cli_inform("Fetching index data for {length(index_symbols)} indices...")
    }
    
    tryCatch({
      # Calculate years to fetch
      years <- seq(lubridate::year(start_date), lubridate::year(end_date))
      
      # Fetch index historical data
      rb3::fetch_marketdata(
        "b3-indexes-historical-data",
        index = index_symbols,
        year = years,
        throttle = TRUE
      )
      
      # Connect and get index data
      indexes <- rb3::indexes_historical_data_get()
      
      # Extract and standardize index data
      index_data <- indexes |>
        dplyr::filter(
          index_name %in% index_symbols,
          refdate >= start_date,
          refdate <= end_date
        ) |>
        dplyr::collect() |>
        # Standardize column names
        dplyr::mutate(
          date = refdate,
          symbol = index_name,
          price_close = close,
          volume = if ("volume" %in% names(.)) volume else NA_real_
        ) |>
        dplyr::select(date, symbol, price_close, volume)
      
    }, error = function(e) {
      if (!quiet) {
        cli::cli_warn("Failed to fetch index data: {e$message}")
      }
    })
  }
  
  # Combine stock and index data
  result <- NULL
  
  if (!is.null(stock_data) && nrow(stock_data) > 0) {
    result <- stock_data
  }
  
  if (!is.null(index_data) && nrow(index_data) > 0) {
    if (is.null(result)) {
      # Add missing columns to match stock data structure
      index_data$price_open <- NA_real_
      index_data$price_high <- NA_real_
      index_data$price_low <- NA_real_
      index_data$trade_quantity <- NA_real_
      index_data$traded_contracts <- NA_real_
      result <- index_data[, names(stock_data)]
    } else {
      # Standardize index data to match stock data columns
      index_std <- index_data |>
        dplyr::mutate(
          price_open = NA_real_,
          price_high = NA_real_,
          price_low = NA_real_,
          trade_quantity = NA_real_,
          traded_contracts = NA_real_
        ) |>
        dplyr::select(names(stock_data))
      
      result <- dplyr::bind_rows(result, index_std)
    }
  }
  
  if (is.null(result) || nrow(result) == 0) {
    cli::cli_abort("No data could be fetched for the specified symbols and date range")
  }
  
  if (!quiet) {
    cli::cli_inform("Successfully fetched {nrow(result)} records for {length(unique(result$symbol))} symbols")
  }
  
  return(result)
}

#' Setup rb3 Environment
#'
#' Initialize rb3 environment with appropriate cache directory and calendar.
#' This function ensures rb3 is properly configured for Brazilian market data.
#'
#' @param cache_dir Character. Directory for caching rb3 data
#' @param quiet Logical. If TRUE, suppresses setup messages
#'
#' @return Invisible NULL (called for side effects)
#' @keywords internal
setup_rb3_environment <- function(cache_dir = NULL, quiet = FALSE) {
  
  if (is.null(cache_dir)) {
    cache_dir <- file.path(tempdir(), "rb3_cache")
  }
  
  # Create cache directory if it doesn't exist
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
    if (!quiet) {
      cli::cli_inform("Created rb3 cache directory: {cache_dir}")
    }
  }
  
  # Set rb3 options
  options(rb3.cachedir = cache_dir)
  
  # Ensure Brazilian business calendar is available
  tryCatch({
    # This will load/create the Brazil/B3 calendar if not available
    bizdays::bizdays("2023-01-01", "2023-01-31", "Brazil/B3")
    if (!quiet) {
      cli::cli_inform("Brazilian business calendar (Brazil/B3) is ready")
    }
  }, error = function(e) {
    if (!quiet) {
      cli::cli_warn("Failed to initialize Brazilian business calendar: {e$message}")
    }
  })
  
  invisible(NULL)
}