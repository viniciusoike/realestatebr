#' Import Real Estate data from the Brazilian Central Bank (DEPRECATED)
#'
#' @description
#' Deprecated since v0.4.0. Use \code{\link{get_dataset}}("bcb_realestate") instead.
#' Imports real estate data from BCB including credit sources, applications,
#' financed units, and real estate indices.
#'
#' @param table Character. One of `'accounting'`, `'application'`, `'indices'`,
#'   `'sources'`, `'units'`, or `'all'` (default).
#' @param cached Logical. If `TRUE`, attempts to load data from cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Tibble with BCB real estate data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source \url{https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario}
#' @keywords internal
get_bcb_realestate <- function(
  table = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  valid_tables <- c(
    "accounting",
    "application",
    "indices",
    "sources",
    "units"
  )

  validate_dataset_params(
    table,
    valid_tables,
    cached,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  # Handle cached data ----
  if (cached) {
    clean_bcb <- handle_dataset_cache(
      "bcb_realestate",
      table = NULL,
      quiet = quiet,
      on_miss = "download"
    )

    if (!is.null(clean_bcb)) {
      clean_bcb <- attach_dataset_metadata(
        clean_bcb,
        source = "cache",
        category = table
      )
    } else {
      # Fallback to fresh download
      clean_bcb <- download_and_process_bcb_data(quiet, max_retries)
    }
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

  # Preserve metadata from clean_bcb
  source_val <- attr(clean_bcb, "source", exact = TRUE)
  if (is.null(source_val)) {
    source_val <- "web"
  }

  tbl_bcb <- attach_dataset_metadata(
    tbl_bcb,
    source = source_val,
    category = table
  )

  # Compute nrow before cli message to avoid serialization issues
  n_records <- nrow(tbl_bcb)
  cli_user(
    "\u2713 BCB real estate data retrieved: {n_records} records",
    quiet = quiet
  )

  return(tbl_bcb)
}

#' Download and Process BCB Real Estate Data
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#' @return Processed BCB real estate data tibble
#' @keywords internal
download_and_process_bcb_data <- function(quiet, max_retries) {
  cli_user("Downloading real estate data from BCB API", quiet = quiet)

  # Download and import most recent data available with retry logic
  bcb <- download_with_retry(
    fn = import_bcb_realestate,
    max_retries = max_retries,
    quiet = quiet,
    desc = "BCB API"
  )

  cli_debug("Processing and cleaning BCB data...")

  # Clean data
  clean_bcb <- clean_bcb_realestate(bcb)

  # Add metadata
  clean_bcb <- attach_dataset_metadata(clean_bcb, source = "web")

  return(clean_bcb)
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
