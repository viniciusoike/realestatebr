#' Import Real Estate data from the Brazilian Central Bank
#'
#' @section Deprecation:
#' This function is deprecated. Use \code{\link{get_dataset}("bcb_realestate")} instead.
#'
#' Imports and cleans real estate data published monthly by the Brazilian Central
#' Bank with modern error handling, progress reporting, and robust API access.
#' Includes credit sources, credit applications, credit operations, financed
#' units, real estate indices.
#'
#' @details
#' If `table = 'all'` a tidy long `tibble` will be returned with all available
#' data. This table can be hard to navigate since it contains several different
#' tables within it. Each series is uniquely identified by the `series_info` column.
#' The `series_info` column is also split along the `v1` to `v5` columns.
#' A complete metadata of each series is available [here](https://www.bcb.gov.br/estatisticas/mercadoimobiliario) (only in Portuguese).
#'
#' Other choices of `table` return a wide `tibble` with informative column
#' names. Available options are: `'accounting'`, `'application'`, `'indices'`,
#' `'sources'`, `'units'`, or `'all'`.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including API access status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed API calls and graceful fallback
#' to cached data when API access fails. BCB API errors are handled with
#' automatic retries and informative error messages.
#'
#' @param table Character. One of `'accounting'`, `'application'`, `'indices'`,
#'   `'sources'`, `'units'`, or `'all'` (default).
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   API calls. Defaults to 3.
#'
#' @source [https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario](https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario)
#' @return If `table = 'all'` returns a `tibble` with 13 columns where:
#' * `series_info`: the full name identifying each series.
#' * `category`: category of the series (first element of `series_info`).
#' * `type`: subcategory of the series (second element of `series_info`).
#' * `v1` to `v5`: elements of `series_info`.
#' * `value`: numeric value of the series.
#' * `abbrev_state`: two letter state abbreviation.
#'
#'   The tibble includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (api or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter mutate select rename_with inner_join tibble
#' @importFrom tidyr pivot_wider unnest
#'
#' @examples \dontrun{
#' # Download all data in long format (with progress)
#' bcb <- get_bcb_realestate(quiet = FALSE)
#'
#' # Get only data on financed units
#' units <- get_bcb_realestate("units")
#'
#' # Use cached data for faster access
#' cached_data <- get_bcb_realestate(cached = TRUE)
#'
#' # Check download metadata
#' attr(units, "download_info")
#' }
get_bcb_realestate <- function(
  table = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c(
    "all",
    "accounting",
    "application",
    "indices",
    "sources",
    "units"
  )

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string"
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
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  # Handle cached data ----
  if (cached) {
    cli_debug("Loading BCB real estate data from cache...")

    tryCatch(
      {
        clean_bcb <- get_dataset("bcb_realestate", source = "github")

        cli_debug("Successfully loaded {nrow(clean_bcb)} records from cache")

        # Add metadata
        attr(clean_bcb, "source") <- "cache"
        attr(clean_bcb, "download_time") <- Sys.time()
        attr(clean_bcb, "download_info") <- list(
          category = table,
          source = "cache"
        )
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from BCB API"
          ))
        }
        # Fallback to fresh download
        clean_bcb <<- download_and_process_bcb_data(quiet, max_retries)
      }
    )
  } else {
    # Download fresh data from BCB API
    clean_bcb <- download_and_process_bcb_data(quiet, max_retries)
  }

  # Return full cleaned table
  if (table == "all") {
    return(clean_bcb)
  }

  # Auxiliary function to pivot_wider thematic tables
  tbl_bcb_wider <- function(cat, id_cols, names_from) {
    clean_bcb |>
      dplyr::filter(category == cat, !stringr::str_detect(type, "[0-9]")) |>
      tidyr::pivot_wider(
        id_cols = id_cols,
        names_from = names_from,
        values_from = "value",
        names_sep = "_",
        names_repair = "universal"
      ) |>
      dplyr::rename_with(~ stringr::str_remove(.x, "(_br)|(br$)"))
  }

  # Tibble with parameters to feed the tbl_bcb_wider function
  params <- dplyr::tibble(
    category_label = c(
      "units",
      "accounting",
      "indices",
      "sources",
      "application"
    ),
    cat = c("imoveis", "contabil", "indices", "fontes", "direcionamento"),
    id_cols = c(
      list(c("date", "abbrev_state")),
      "date",
      "date",
      "date",
      "date"
    ),
    names_from = list(
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1", "v2")
    )
  )
  # Use purrr::pmap to apply function
  params <- params |>
    dplyr::mutate(
      tab = purrr::pmap(list(cat, id_cols, names_from), tbl_bcb_wider)
    )
  # Subset for specific category
  tbl_bcb <- params |>
    dplyr::filter(category_label == table) |>
    tidyr::unnest(cols = tab) |>
    dplyr::select(-cat, -id_cols, -names_from)

  # Add metadata attributes
  attr(tbl_bcb, "source") <- if (is.null(attr(clean_bcb, "source"))) {
    "api"
  } else {
    attr(clean_bcb, "source")
  }
  attr(tbl_bcb, "download_time") <- if (
    is.null(attr(clean_bcb, "download_time"))
  ) {
    Sys.time()
  } else {
    attr(clean_bcb, "download_time")
  }
  attr(tbl_bcb, "download_info") <- if (
    is.null(attr(clean_bcb, "download_info"))
  ) {
    list(category = table, source = "api")
  } else {
    attr(clean_bcb, "download_info")
  }

  cli_user("✓ BCB real estate data retrieved: {nrow(tbl_bcb)} records", quiet = quiet)

  return(tbl_bcb)
}

#' Download and Process BCB Real Estate Data with Retry Logic
#'
#' Internal function to download and process BCB real estate data with
#' retry logic and proper error handling.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Processed BCB real estate data tibble
#' @keywords internal
download_and_process_bcb_data <- function(quiet, max_retries) {
  cli_user("Downloading real estate data from BCB API", quiet = quiet)

  # Download and import most recent data available with retry logic
  bcb <- import_bcb_realestate_robust(quiet = quiet, max_retries = max_retries)

  cli_debug("Processing and cleaning BCB data...")

  # Clean data
  clean_bcb <- clean_bcb_realestate(bcb)

  # Add metadata
  attr(clean_bcb, "source") <- "api"
  attr(clean_bcb, "download_time") <- Sys.time()
  attr(clean_bcb, "download_info") <- list(
    source = "api",
    records_processed = nrow(clean_bcb)
  )

  return(clean_bcb)
}

#' Import BCB Real Estate Data with Robust Error Handling
#'
#' Modern version of import_bcb_realestate with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Raw BCB data or error
#' @keywords internal
import_bcb_realestate_robust <- function(quiet, max_retries) {
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Try the original import function
        result <- import_bcb_realestate()
        return(result)
      },
      error = function(e) {
        last_error <<- e$message

        if (!quiet && attempts <= max_retries) {
          cli::cli_warn(c(
            "BCB API request failed (attempt {attempts}/{max_retries + 1})",
            "x" = "Error: {e$message}",
            "i" = "Retrying in {min(attempts * 0.5, 3)} second{?s}..."
          ))
        }

        # Add delay before retry
        if (attempts <= max_retries) {
          Sys.sleep(min(attempts * 0.5, 3))
        }
      }
    )
  }

  # All attempts failed
  cli::cli_abort(c(
    "Failed to download BCB real estate data",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and BCB API status"
  ))
}


import_bcb_realestate <- function() {
  tryCatch(
    {
      url <- "https://olinda.bcb.gov.br/olinda/servico/MercadoImobiliario/versao/v1/odata/mercadoimobiliario?$format=text/csv&$select=Data,Info,Valor"

      # Create a temporary file name
      temp_file <- tempfile(fileext = ".csv")

      message("Downloading real estate data from the Brazilian Central Bank.")

      # Download csv file with error checking
      download_result <- utils::download.file(
        url,
        destfile = temp_file,
        mode = "wb",
        quiet = TRUE
      )

      # Check if download was successful
      if (download_result != 0) {
        stop("Failed to download file from BCB")
      }

      # Read the data
      df <- readr::read_csv(temp_file, col_types = "Dcc")

      # Check if data is empty
      if (nrow(df) == 0) {
        stop("Downloaded file contains no data")
      }

      return(df)
    },
    error = function(e) {
      message(sprintf("Error in import_bcb_realestate: %s", e$message))
      return(NULL)
    },
    warning = function(w) {
      message(sprintf("Warning in import_bcb_realestate: %s", w$message))
      return(NULL)
    },
    finally = {
      # Clean up temporary file if it exists
      if (exists("temp_file") && file.exists(temp_file)) {
        unlink(temp_file)
      }
    }
  )
}

clean_bcb_realestate <- function(df) {
  # Named vector to help split series_info into smaller categories v1-v8 (for filtering)
  new_names <- c(
    "home_equity" = "home-equity",
    "risco_operacao" = "risco-operacao",
    "d_mais" = "d-mais",
    "ivg_r" = "ivg-r",
    "mvg_r" = "mvg-r"
  )

  # Basic clean: renames columns and convert types
  df <- df |>
    dplyr::rename(date = Data, series_info = Info, value = Valor) |>
    dplyr::mutate(
      # Convert to numeric
      value = stringr::str_replace(value, ",", "."),
      value = suppressWarnings(as.numeric(value)),
      # Swap some elements to help split the series_info column
      series_info = stringr::str_replace_all(series_info, new_names),
      # Define year and month columns
      year = lubridate::year(date),
      month = lubridate::month(date),
    )

  # Split the info column into several columns
  df <- df |>
    tidyr::separate_wider_delim(
      series_info,
      delim = "_",
      names = c(
        "category",
        "type",
        "v1",
        "v2",
        "v3",
        "v4",
        "v5",
        "v6",
        "v7",
        "v8"
      ),
      too_few = "align_start",
      cols_remove = FALSE
    )

  # Finds region
  uf_abb <- "br|ro|ac|am|rr|pa|ap|to|ma|pi|ce|rn|pb|pe|al|se|ba|mg|es|rj|sp|pr|sc|rs|ms|mt|go|df"
  # Creates the abbrev_state column
  df <- df |>
    dplyr::mutate(
      # State abbreviation (if exists) is always in the last two elements of the string
      abbrev_state = stringr::str_extract(
        stringr::str_sub(series_info, -2, -1),
        uf_abb
      ),
      # Convert to upper case
      abbrev_state = stringr::str_to_upper(abbrev_state),
      # If no element was found, default to BR (Brazil)
      abbrev_state = ifelse(is.na(abbrev_state), "BR", abbrev_state)
    )

  # Remove columns that are full NA
  df <- dplyr::select(df, dplyr::where(~ !all(is.na(.x))))

  # Rearrange columns
  df <- df |>
    dplyr::arrange(series_info) |>
    dplyr::arrange(date)

  return(df)
}
