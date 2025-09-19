#' Get Residential Property Price Index Data
#'
#' Quickly import all Residential Price Indexes in Brazil with modern error
#' handling, progress reporting, and robust data coordination across multiple sources.
#' This function returns a convenient standardized output.
#'
#' @details
#' There are several residential property price indexes in Brazil. This function
#' is a wrapper around all of the `get_rppi_*` functions that conveniently returns
#' a standardized output. The `index` column is the index-number, the `chg` column
#' is the percent change in the index number, and `acum12m` is the 12-month
#' accumulated variation in the index number.
#'
#' It's important to note the IQA Index is a raw price and not a index-number.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including coordination status across multiple RPPI data sources.
#'
#' @section Error Handling:
#' The function includes comprehensive error handling for coordinating multiple
#' data sources and standardizing outputs across different RPPI functions.
#'
#' @param table Character. Which dataset to return: "sale" (default), "rent", or "all".
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached If `TRUE` downloads the cached data from the GitHub repository.
#'   This is a faster option but not recommended for daily data.
#' @param stack If `TRUE` returns a single `tibble` identified by a `source` column.
#'   If `FALSE` returns a named `list` (default).
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting across all sources.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   operations across all RPPI data sources. Defaults to 3.
#'
#' @return Either a named `list` or a `tibble` (if `stack = TRUE`).
#'   The return includes metadata attributes when stacked:
#'   \\describe{
#'     \\item{download_info}{List with coordination statistics}
#'     \\item{source}{Data source coordination method}
#'     \\item{download_time}{Timestamp of coordination}
#'   }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter mutate select bind_rows
#' @importFrom tidyr pivot_wider
#'
#' @examples \dontrun{
#' # Get RPPI sales data (with progress)
#' sales <- get_rppi("sale", quiet = FALSE)
#'
#' # Get RPPI rent data
#' rent <- get_rppi("rent")
#'
#' # Get stacked data for easier analysis
#' all_data <- get_rppi("sale", stack = TRUE)
#'
#' # Check coordination metadata
#' attr(all_data, "download_info")
#' }
get_rppi <- function(
  table = "sale",
  category = NULL,
  cached = FALSE,
  stack = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation and backward compatibility ----
  valid_tables <- c("sale", "rent", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn(c(
      "Parameter {.arg category} is deprecated",
      "i" = "Use {.arg table} parameter instead",
      ">" = "This will be removed in a future version"
    ))
    table <- category
  }

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

  if (!is.logical(stack) || length(stack) != 1) {
    cli::cli_abort("{.arg stack} must be a logical value")
  }

  if (!is.logical(quiet) || length(quiet) != 1) {
    cli::cli_abort("{.arg quiet} must be a logical value")
  }

  if (!is.numeric(max_retries) || length(max_retries) != 1 || max_retries < 1) {
    cli::cli_abort("{.arg max_retries} must be a positive integer")
  }

  # Coordinate data collection ----
  if (!quiet) {
    cli::cli_inform("Coordinating RPPI data collection across multiple sources...")
  }

  # Import Index data from FipeZap
  if (!quiet) {
    cli::cli_inform("Fetching FipeZap data...")
  }
  fipezap <- get_rppi_fipezap(
    cached = cached,
    quiet = quiet,
    max_retries = max_retries
  )

  # Standardize output
  fipezap <- fipezap |>
    # Select only the residential index and filter by operation
    dplyr::filter(
      market == "residential",
      rent_sale == table,
      variable %in% c("index", "chg", "acum12m"),
      rooms == "total"
    ) |>
    # Convert to wide
    tidyr::pivot_wider(
      id_cols = c("date", "name_muni"),
      names_from = "variable",
      values_from = "value"
    ) |>
    # Swap "Índice Fipezap+" for "Brazil"
    dplyr::mutate(
      name_muni = ifelse(name_muni == "Índice Fipezap+", "Brazil", name_muni)
    )

  # Handle "all" case by returning both rent and sale data
  if (table == "all") {
    if (!quiet) {
      cli::cli_inform("Fetching all RPPI data sources (rent and sale)...")
    }

    # Get both rent and sale data
    rent_data <- get_rppi(table = "rent", cached = cached, stack = stack, quiet = quiet, max_retries = max_retries)
    sale_data <- get_rppi(table = "sale", cached = cached, stack = stack, quiet = quiet, max_retries = max_retries)

    result <- list(
      rent = rent_data,
      sale = sale_data
    )

    # Add metadata for "all" case
    if (stack) {
      # If stacked, combine both datasets
      result <- dplyr::bind_rows(
        dplyr::mutate(rent_data, transaction_type = "rent"),
        dplyr::mutate(sale_data, transaction_type = "sale")
      )

      attr(result, "source") <- "coordinated"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = table,
        total_records = nrow(result),
        transaction_types = c("rent", "sale")
      )
    } else {
      attr(result, "source") <- "coordinated"
      attr(result, "download_time") <- Sys.time()
      attr(result, "download_info") <- list(
        table = table,
        sources = c("rent", "sale")
      )
    }

    return(result)
  }

  if (table == "rent") {
    if (!quiet) {
      cli::cli_inform("Fetching rent-specific RPPI data sources...")
    }

    # Get Secovi-SP
    if (!quiet) {
      cli::cli_inform("Fetching Secovi-SP data...")
    }
    secovi <- get_rppi_secovi_sp(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )

    # Get IQA
    if (!quiet) {
      cli::cli_inform("Fetching QuintoAndar IQA data...")
    }
    iqa <- get_rppi_iqa(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )

    # Get IVAR
    if (!quiet) {
      cli::cli_inform("Fetching IVAR data...")
    }
    ivar <- get_rppi_ivar(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )
    # Standardize output
    ivar <- dplyr::select(ivar, date, name_muni, index, chg, acum12m)

    if (!quiet) {
      cli::cli_inform("Finalizing rent RPPI data coordination...")
    }

    # Put all series in a named list
    rppi <- list(iqa, ivar, secovi, fipezap)
    # If stack is TRUE name the list and then bind the rows
    if (stack) {
      names(rppi) <- c("IQA", "IVAR", "Secovi-SP", "FipeZap")
      rppi <- dplyr::bind_rows(rppi, .id = "source")

      # Add coordination metadata for stacked results
      attr(rppi, "source") <- "coordinated"
      attr(rppi, "download_time") <- Sys.time()
      attr(rppi, "download_info") <- list(
        table = table,
        sources_coordinated = c("IQA", "IVAR", "Secovi-SP", "FipeZap"),
        coordination_method = "stacked"
      )
    } else {
      # Else just use simple names and return as list
      names(rppi) <- c("iqa", "ivar", "secovi_sp", "fipezap")
    }
  }

  if (table == "sale") {
    if (!quiet) {
      cli::cli_inform("Fetching sales-specific RPPI data sources...")
    }

    # Get IVGR
    if (!quiet) {
      cli::cli_inform("Fetching BCB IVGR data...")
    }
    ivgr <- get_rppi_ivgr(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )

    # Standardize output
    ivgr <- dplyr::mutate(ivgr, name_muni = "Brazil")
    ivgr <- dplyr::select(ivgr, -dplyr::any_of("name_geo"))

    # Get IGMI and standardize output
    if (!quiet) {
      cli::cli_inform("Fetching ABECIP IGMI data...")
    }
    igmi <- get_rppi_igmi(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )
    igmi <- dplyr::mutate(igmi, name_muni = ifelse(name_muni == "Brasil", "Brazil", name_muni))
    if (!quiet) {
      cli::cli_inform("Finalizing sales RPPI data coordination...")
    }

    # Put all series in a named list
    rppi <- list(igmi, ivgr, fipezap)
    # If stack is TRUE name the list and then bind the rows
    if (stack) {
      names(rppi) <- c("IGMI-R", "IVG-R", "FipeZap")
      rppi <- dplyr::bind_rows(rppi, .id = "source")

      # Add coordination metadata for stacked results
      attr(rppi, "source") <- "coordinated"
      attr(rppi, "download_time") <- Sys.time()
      attr(rppi, "download_info") <- list(
        table = table,
        sources_coordinated = c("IGMI-R", "IVG-R", "FipeZap"),
        coordination_method = "stacked"
      )
    } else {
      # Else just use simple names and return as list
      names(rppi) <- c("igmi_r", "ivg_r", "fipezap")
    }
  }

  # Final coordination reporting
  if (!quiet) {
    if (stack) {
      cli::cli_inform("Successfully coordinated {table} RPPI data with {nrow(rppi)} total records")
    } else {
      sources_count <- length(rppi)
      cli::cli_inform("Successfully coordinated {table} RPPI data from {sources_count} source{?s}")
    }
  }

  return(rppi)

}

#' Import BCB IVGR Data with Robust Error Handling
#'
#' Internal function to download IVGR data from BCB API with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Downloaded BCB API data
#' @keywords internal
import_bcb_ivgr_robust <- function(quiet, max_retries) {
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Try downloading from BCB API
        result <- suppressMessages(
          GetBCBData::gbcbd_get_series(
            id = 21340,
            first.date = as.Date("2001-03-01")
          )
        )

        # Validate we got some data
        if (nrow(result) == 0) {
          stop("BCB API returned no data for series 21340")
        }

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
    "Failed to download IVGR data from BCB API",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and BCB API status"
  ))
}

#' Get the IVGR Sales Index
#'
#' Imports the IVG-R sales index with modern error handling, progress reporting,
#' and robust BCB API access capabilities.
#'
#' @details
#' The IVG-R, or Residential Real Estate Collateral Value Index, is a monthly median
#' sales index based on bank appraisals in Brazil. The index is calculated by the
#' Brazilian Central Bank and is representative of the entire country. The index estimates
#' the long-run trend in home prices and encompasses Brazil's major metropolitan regions.
#' Trend in prices are obtained by the familiar Hodrick-Prescott filter (lambda = 3600)
#' applied to each city. The IVG-R is a weighted average of these price trends.
#'
#' Median property price indices suffer from composition bias and cannot account
#' for quality changes across the housing stock.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including BCB API access status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed BCB API calls and robust
#' error handling for data processing operations.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   BCB API calls. Defaults to 3.
#'
#' @return A `tibble` with the IVGR Index where:
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with download statistics}
#'   \item{source}{Data source used (api or cache)}
#'   \item{download_time}{Timestamp of download}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr rename select mutate
#' @seealso [get_rppi()]
#'
#' @references Banco Central do Brasil (2018) "Índice de Valores de Garantia de Imóveis Residenciais Financiados (IVG-R). Seminário de Metodologia do IBGE."
#'
#' @examples \dontrun{
#' # Get IVGR index (with progress)
#' ivgr <- get_rppi_ivgr(quiet = FALSE)
#'
#' # Use cached data for faster access
#' cached_data <- get_rppi_ivgr(cached = TRUE)
#'
#' # Check download metadata
#' attr(ivgr, "download_info")
#' }
get_rppi_ivgr <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
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
    if (!quiet) {
      cli::cli_inform("Loading IVGR data from cache...")
    }

    tryCatch(
      {
        # Use new unified architecture for cached data
        ivgr <- get_dataset("rppi", source = "github", category = "sale")
        ivgr <- dplyr::filter(ivgr, source == "IVG-R")

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(ivgr)} IVGR records from cache"
          )
        }

        # Add metadata
        attr(ivgr, "source") <- "cache"
        attr(ivgr, "download_time") <- Sys.time()
        attr(ivgr, "download_info") <- list(
          source = "cache"
        )

        return(ivgr)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from BCB API"
          ))
        }
      }
    )
  }

  # Download and process data ----
  if (!quiet) {
    cli::cli_inform("Downloading IVGR data from BCB API...")
  }

  # Import data from BCB API with retry logic
  ivgr <- import_bcb_ivgr_robust(quiet = quiet, max_retries = max_retries)

  if (!quiet) {
    cli::cli_inform("Processing and cleaning IVGR data...")
  }

  # Clean data
  clean_ivgr <- ivgr |>
    # Rename columns and select only date and index
    dplyr::rename(date = ref.date, index = value) |>
    dplyr::select(date, index) |>
    dplyr::mutate(
      name_geo = "Brazil",
      chg = index / dplyr::lag(index) - 1,
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
    )

  # Add metadata attributes
  attr(clean_ivgr, "source") <- "api"
  attr(clean_ivgr, "download_time") <- Sys.time()
  attr(clean_ivgr, "download_info") <- list(
    series_id = 21340,
    source = "api"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed IVGR data with {nrow(clean_ivgr)} records")
  }

  return(tidyr::as_tibble(clean_ivgr))

}

#' Download IGMI Excel File with Robust Error Handling
#'
#' Internal function to download IGMI Excel file from ABECIP website with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to downloaded temporary Excel file
#' @keywords internal
download_igmi_excel_robust <- function(quiet, max_retries) {
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Scrape download URL from ABECIP website
        base_url <- "https://www.abecip.org.br/igmi-r-abecip/serie-historica"
        parsed <- xml2::read_html(base_url)
        node <- rvest::html_element(parsed, xpath = "//div[@class='bloco_anexo']/a")
        download_url <- rvest::html_attr(node, "href")

        if (is.na(download_url)) {
          stop("Could not find Excel download link on ABECIP website")
        }

        # Download the Excel file
        temp_path <- tempfile("igmi.xlsx")
        download_result <- try(
          download.file(download_url, destfile = temp_path, mode = "wb", quiet = TRUE),
          silent = TRUE
        )

        if (inherits(download_result, "try-error") || download_result != 0) {
          stop("Failed to download Excel file from ABECIP")
        }

        # Verify file exists and has content
        if (!file.exists(temp_path) || file.size(temp_path) == 0) {
          stop("Downloaded Excel file is empty or missing")
        }

        return(temp_path)
      },
      error = function(e) {
        last_error <<- e$message

        if (!quiet && attempts <= max_retries) {
          cli::cli_warn(c(
            "IGMI Excel download failed (attempt {attempts}/{max_retries + 1})",
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
    "Failed to download IGMI Excel file from ABECIP",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and ABECIP website status"
  ))
}

#' Get the IGMI Sales Index
#'
#' Imports the IGMI sales index for all cities available with modern error
#' handling, progress reporting, and robust Excel download and processing capabilities.
#'
#' @details
#' The IGMI-R, or Residential Real Estate Index, is a hedonic sales index based on
#' bank appraisal reports. The index is available for Brazil + 10 capital cities.
#'
#' Hedonic prices indices account for both composition bias and quality
#' differentials across the housing stock. The index is maintained by Abecip in
#' parternship with FGV.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including web scraping, Excel download status, and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed web scraping and Excel download
#' operations, with robust error handling for multi-city data processing.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   web scraping and download operations. Defaults to 3.
#'
#' @return A `tibble` stacking data for all cities. The national IGMI-R is defined
#' as the series with `name_muni == 'Brazil'`.
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with download statistics}
#'   \item{source}{Data source used (web or cache)}
#'   \item{download_time}{Timestamp of download}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr rename mutate group_by ungroup left_join select filter
#' @importFrom tidyr pivot_longer
#'
#' @examples \dontrun{
#' # Get IGMI index (with progress)
#' igmi <- get_rppi_igmi(quiet = FALSE)
#'
#' # Use cached data for faster access
#' cached_data <- get_rppi_igmi(cached = TRUE)
#'
#' # Check download metadata
#' attr(igmi, "download_info")
#' }
get_rppi_igmi <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
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
    if (!quiet) {
      cli::cli_inform("Loading IGMI data from cache...")
    }

    tryCatch(
      {
        # Use new unified architecture for cached data
        igmi <- get_dataset("rppi", source = "github", category = "sale")
        igmi <- dplyr::filter(igmi, source == "IGMI-R")

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(igmi)} IGMI records from cache"
          )
        }

        # Add metadata
        attr(igmi, "source") <- "cache"
        attr(igmi, "download_time") <- Sys.time()
        attr(igmi, "download_info") <- list(
          source = "cache"
        )

        return(igmi)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from ABECIP"
          ))
        }
      }
    )
  }

  # Download and process data ----
  if (!quiet) {
    cli::cli_inform("Downloading IGMI data from ABECIP website...")
  }

  # Download Excel file with retry logic
  temp_path <- download_igmi_excel_robust(quiet = quiet, max_retries = max_retries)

  if (!quiet) {
    cli::cli_inform("Processing IGMI Excel data...")
  }

  # Import data from spreadsheet
  igmi <- readxl::read_excel(
    path = temp_path,
    skip = 4,
    # Use janitor to name repair the columns
    .name_repair = janitor::make_clean_names
  )

  if (!quiet) {
    cli::cli_inform("Setting up city mapping and cleaning data...")
  }

  # Auxiliary data.frame to vlookup city names
  dim_geo <- data.frame(
    name_muni = c(
      "Belo Horizonte", "Brasil", "Brasília", "Curitiba", "Fortaleza", "Goiânia",
      "Porto Alegre", "Recife", "Rio De Janeiro", "Salvador", "São Paulo"),
    name_simplified = c(
      "belo_horizonte", "brasil", "brasilia", "curitiba", "fortaleza", "goiania",
      "porto_alegre", "recife", "rio_de_janeiro", "salvador", "sao_paulo")
  )

  # Clean the data
  clean_igmi <- igmi |>
    # Rename date column
    dplyr::rename(date = mes) |>
    # Parse date to Date format
    dplyr::mutate(date = suppressWarnings(readr::parse_date(date, format = "%Y %m"))) |>
    # Remove all NAs in date column
    dplyr::filter(!is.na(date)) |>
    # Drop last column (12-month brazil)
    dplyr::select(-var_percent_12_meses)

  if (!quiet) {
    cli::cli_inform("Converting to long format and calculating changes...")
  }

  clean_igmi <- clean_igmi |>
    # Convert data to long (previous column names are now 'name_simplified')
    tidyr::pivot_longer(
      cols = -date,
      names_to = "name_simplified",
      values_to = "index"
    ) |>
    # Compute MoM and YoY change
    dplyr::group_by(name_simplified) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
    ) |>
    dplyr::ungroup() |>
    dplyr::left_join(dim_geo, by = "name_simplified") |>
    # Select column order
    dplyr::select(date, name_muni, index, chg, acum12m)

  # Add metadata attributes
  attr(clean_igmi, "source") <- "web"
  attr(clean_igmi, "download_time") <- Sys.time()
  attr(clean_igmi, "download_info") <- list(
    cities_processed = length(unique(clean_igmi$name_muni)),
    source = "web"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed IGMI data with {nrow(clean_igmi)} records")
  }

  return(clean_igmi)

}

#' Import IQA CSV Data with Robust Error Handling
#'
#' Internal function to download IQA CSV data with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Downloaded CSV data as tibble
#' @keywords internal
import_iqa_csv_robust <- function(quiet, max_retries) {
  url <- "https://publicfiles.data.quintoandar.com.br/Indice_QuintoAndar.csv"
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Try downloading and reading the CSV
        result <- readr::read_csv(url, col_types = "cDn")

        # Validate we got some data
        if (nrow(result) == 0) {
          stop("Downloaded CSV file contains no data")
        }

        return(result)
      },
      error = function(e) {
        last_error <<- e$message

        if (!quiet && attempts <= max_retries) {
          cli::cli_warn(c(
            "IQA CSV download failed (attempt {attempts}/{max_retries + 1})",
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
    "Failed to download QuintoAndar IQA data",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and QuintoAndar API status"
  ))
}

#' Get data from The QuintoAndar Rental Index (IQA)
#'
#' Imports the QuintoAndar Rental Index for all cities available with modern
#' error handling, progress reporting, and robust CSV download capabilities.
#'
#' @details
#' The IQA, or QuintoAndar Rental Index, is a median stratified index calculated
#' for Brazil's two main cities: Rio de Janeiro and São Paulo. The source of the
#' data are all the new rent contracts managed by QuintoAndar. The Index includes
#' only apartments and similar units such as studios and flats.
#'
#' Despite the name "Index", the IQA actually provides a raw-price and not an index-number.
#' This means that the `rent_price` column is the median rent per square meter.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including CSV download status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed CSV downloads and robust
#' error handling for data processing operations.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   CSV download operations. Defaults to 3.
#'
#' @return A `tibble` QuintoAndar Rental Index where:
#'
#' * `rent_price` is the median rent price per squared meter.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with download statistics}
#'   \item{source}{Data source used (web or cache)}
#'   \item{download_time}{Timestamp of download}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr select mutate group_by ungroup filter
#' @seealso [get_rppi()]
#'
#' @examples \dontrun{
#' # Get the IQA index (with progress)
#' iqa <- get_rppi_iqa(quiet = FALSE)
#'
#' # Subset Rio de Janeiro
#' rio <- subset(iqa, name_muni == "Rio de Janeiro")
#'
#' # Use cached data for faster access
#' cached_data <- get_rppi_iqa(cached = TRUE)
#'
#' # Check download metadata
#' attr(iqa, "download_info")
#' }
get_rppi_iqa <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
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
    if (!quiet) {
      cli::cli_inform("Loading QuintoAndar IQA data from cache...")
    }

    tryCatch(
      {
        iqa <- get_dataset("rppi", source = "github", category = "rent")
        iqa <- dplyr::filter(iqa, source == "IQA")

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(iqa)} IQA records from cache"
          )
        }

        # Add metadata
        attr(iqa, "source") <- "cache"
        attr(iqa, "download_time") <- Sys.time()
        attr(iqa, "download_info") <- list(
          source = "cache"
        )

        return(iqa)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from QuintoAndar"
          ))
        }
      }
    )
  }

  # Download and process data ----
  if (!quiet) {
    cli::cli_inform("Downloading IQA data from QuintoAndar...")
  }

  # Import data with retry logic
  iqa <- import_iqa_csv_robust(quiet = quiet, max_retries = max_retries)

  if (!quiet) {
    cli::cli_inform("Processing and cleaning IQA data...")
  }

  # Clean data
  clean_iqa <- iqa |>
    # Rename columns
    dplyr::select(
      date = month,
      name_muni = city_name,
      rent_price = weighted_median_contract_rent_per_sqm
    ) |>
    # Convert to appropriate types
    dplyr::mutate(
      # Capitalize strings
      name_muni = stringr::str_to_title(name_muni, locale = "pt_BR"),
      # Convert rent price to numeric
      rent_price = as.numeric(rent_price)
    )

  if (!quiet) {
    cli::cli_inform("Calculating monthly and annual changes...")
  }

  # Calculate MoM change in index and 12-month change
  clean_iqa <- clean_iqa |>
    dplyr::group_by(name_muni) |>
    dplyr::mutate(
      chg = rent_price / dplyr::lag(rent_price) - 1,
      acum12m = rent_price / dplyr::lag(rent_price, n = 12) - 1
    ) |>
    dplyr::ungroup()

  # Add metadata attributes
  attr(clean_iqa, "source") <- "web"
  attr(clean_iqa, "download_time") <- Sys.time()
  attr(clean_iqa, "download_info") <- list(
    cities_processed = length(unique(clean_iqa$name_muni)),
    source = "web"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed IQA data with {nrow(clean_iqa)} records")
  }

  return(clean_iqa)

}

#' Get the IVAR rent Index
#'
#' Imports the IVAR rent index for all cities available with modern
#' error handling, progress reporting, and robust data processing capabilities.
#'
#' @details
#' The IVAR, or Residential Rent Variation Index, is a repeat-rent index, meaning
#' it compares the same housing unit across different points in time. The source
#' of the Index are rental contracts provided by brokers to IBRE (FGV). Data is available
#' in four major Brazilian cities; the national index is calculated as a weighted
#' average of the four individual series.
#'
#' Although other price indices such as the IGP-M are commonly used in rental
#' contracts in Brazil, the IVAR is theoretically more appropriate since it
#' measures only rent prices.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including data processing and calculation steps.
#'
#' @section Error Handling:
#' The function includes robust error handling for data processing operations
#' and validation of required data dependencies.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   data processing operations. Defaults to 3.
#'
#' @return A `tibble` stacking data for all cities. The national IVAR is defined
#' as the series with `name_muni == 'Brazil'`.
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with download statistics}
#'   \item{source}{Data source used (web or cache)}
#'   \item{download_time}{Timestamp of download}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter select mutate group_by ungroup left_join
#' @seealso [get_rppi()]
#' @examples \dontrun{
#' # Get the IVAR index (with progress)
#' ivar <- get_rppi_ivar(quiet = FALSE)
#'
#' # Subset national index
#' brasil <- subset(ivar, name_muni == "Brazil")
#'
#' # Use cached data for faster access
#' cached_data <- get_rppi_ivar(cached = TRUE)
#'
#' # Check download metadata
#' attr(ivar, "download_info")
#' }
get_rppi_ivar <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
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
    if (!quiet) {
      cli::cli_inform("Loading IVAR data from cache...")
    }

    tryCatch(
      {
        ivar <- get_dataset("rppi", source = "github", category = "rent")
        ivar <- dplyr::filter(ivar, source == "IVAR")

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(ivar)} IVAR records from cache"
          )
        }

        # Add metadata
        attr(ivar, "source") <- "cache"
        attr(ivar, "download_time") <- Sys.time()
        attr(ivar, "download_info") <- list(
          source = "cache"
        )

        return(ivar)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh data processing"
          ))
        }
      }
    )
  }

  # Download and process data ----
  if (!quiet) {
    cli::cli_inform("Processing IVAR data from FGV sources...")
  }

  # Check for required data dependencies
  if (!exists("fgv_data") || !exists("dim_city")) {
    cli::cli_abort(c(
      "Required data dependencies not available",
      "x" = "This function requires {.pkg fgv_data} and {.pkg dim_city} objects",
      "i" = "Please ensure all package data is properly loaded"
    ))
  }

  if (!quiet) {
    cli::cli_inform("Preparing city mapping data...")
  }

  # Set up city mapping for IVAR cities
  ivar_cities <- dim_city |>
    dplyr::filter(code_muni %in% c(3550308, 4314902, 3304557, 3106200)) |>
    dplyr::select(name_simplified, name_muni, abbrev_state)

  if (!quiet) {
    cli::cli_inform("Extracting IVAR data series...")
  }

  # Filter IVAR from fgv_data, select columns and change the value column name
  ivar <- fgv_data |>
    dplyr::filter(stringr::str_detect(name_simplified, "^ivar")) |>
    dplyr::select(date, name_simplified, index = value) |>
    dplyr::filter(!is.na(index))

  if (!quiet) {
    cli::cli_inform("Calculating monthly and annual changes...")
  }

  # Group by city and compute percent change and YoY change
  ivar <- ivar |>
    dplyr::group_by(name_simplified) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
    ) |>
    dplyr::ungroup()

  if (!quiet) {
    cli::cli_inform("Joining with city metadata...")
  }

  # Join with proper city names and select column order
  ivar <- ivar |>
    dplyr::mutate(
      name_simplified = stringr::str_remove(name_simplified, "ivar_")
    ) |>
    dplyr::left_join(ivar_cities, by = "name_simplified") |>
    dplyr::mutate(
      name_muni = ifelse(name_simplified == "brazil", "Brazil", name_muni),
      abbrev_state = ifelse(name_simplified == "brazil", "BR", abbrev_state)
    ) |>
    dplyr::select(
      date, name_muni, index, chg, acum12m, name_simplified, abbrev_state
    )

  # Add metadata attributes
  attr(ivar, "source") <- "web"
  attr(ivar, "download_time") <- Sys.time()
  attr(ivar, "download_info") <- list(
    cities_processed = length(unique(ivar$name_muni)),
    source = "web"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed IVAR data with {nrow(ivar)} records")
  }

  return(ivar)

}

#' Get the Secovi-SP Rent Index
#'
#' Imports the Secovi-SP rent index for São Paulo with modern error handling
#' and progress reporting capabilities.
#'
#' @param cached Logical. If `TRUE`, attempts to load data from package cache.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#' @param max_retries Integer. Maximum number of retry attempts.
#' @keywords internal
#' @return A `tibble` with the Secovi Rent Index where:
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
get_rppi_secovi_sp <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Loading Secovi-SP data from cache...")
    }

    tryCatch(
      {
        secovi <- get_dataset("rppi", source = "github", category = "rent")
        secovi <- dplyr::filter(secovi, source == "Secovi-SP")
        return(secovi)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn("Failed to load cached data, falling back to fresh download")
        }
      }
    )
  }

  # Use the modernized get_secovi function
  secovi <- get_secovi(
    category = "rent",
    cached = FALSE,
    quiet = quiet,
    max_retries = max_retries
  )

  secovi_index <- secovi |>
    dplyr::filter(category == "rent", variable == "rent_price") |>
    dplyr::rename(index = value) |>
    dplyr::mutate(
      name_muni = "São Paulo",
      chg = index / dplyr::lag(index) - 1,
      acum12m = zoo::rollapplyr(1 + chg, width = 12, FUN = prod, fill = NA) - 1
    ) |>
    dplyr::select(date, name_muni, index, chg, acum12m)

  return(secovi_index)

}

#' Download FipeZap Excel File with Robust Error Handling
#'
#' Internal function to download FipeZap Excel file with retry logic.
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to downloaded temporary Excel file
#' @keywords internal
download_fipezap_excel <- function(quiet, max_retries) {
  url <- "https://downloads.fipe.org.br/indices/fipezap/fipezap-serieshistoricas.xlsx"
  temp_path <- tempfile("fipezap.xlsx")
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Try downloading the Excel file
        response <- httr::GET(
          url = url,
          httr::write_disk(path = temp_path, overwrite = TRUE)
        )

        # Check if download was successful
        httr::stop_for_status(response)

        # Verify file exists and has content
        if (!file.exists(temp_path) || file.size(temp_path) == 0) {
          stop("Downloaded file is empty or missing")
        }

        return(temp_path)
      },
      error = function(e) {
        last_error <<- e$message

        if (!quiet && attempts <= max_retries) {
          cli::cli_warn(c(
            "FipeZap Excel download failed (attempt {attempts}/{max_retries + 1})",
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
    "Failed to download FipeZap Excel file",
    "x" = "All {max_retries + 1} attempt{?s} failed",
    "i" = "Last error: {last_error}",
    "i" = "Check your internet connection and FipeZap website status"
  ))
}

#' Get the FipeZap RPPI
#'
#' Import residential and commercial prices indices from FipeZap with modern
#' error handling, progress reporting, and robust Excel download capabilities.
#'
#' @details
#' The FipeZap Index is a monthly median stratified index calculated across several
#' cities in Brazil. This function imports both the rental and the sale index for
#' all cities. The Index is based on online listings of the Zap Imóveis group and is
#' stratified by number of rooms. The overall city index is a weighted sum of median
#' prices by room/region.
#'
#' The residential Index includes only apartments and similar units such as studios and flats.
#'
#' Choosing a specific city will only filter the final results and will not save
#' processing/downloading time.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including Excel download status and data processing steps for multiple sheets.
#'
#' @section Error Handling:
#' The function includes retry logic for failed Excel downloads and robust
#' error handling for multi-sheet Excel processing operations.
#'
#' @param city Either the name of the city or `'all'` (default). If the chosen
#' city name is not available the full table will be returned.
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   Excel download operations. Defaults to 3.
#'
#' @return A `tibble` with RPPI data for all selected cities where:
#'
#' * `market` - specifices either `'commercial'` or `'residential'`
#' * `rent_sale` - specifies either `'rent'` or `'sale'`
#' * `variable` - 'index' is the index-number, 'chg' is the monthly change, 'acum12m' is the year-on-year change, 'price_m2' is the raw sale/rent price per squared meter, and 'yield' is the gross rental yield.
#' * `rooms` - number of rooms (`total` is the average)
#'
#' The national index is defined as the series with `name_muni == 'Índice Fipezap+'`.
#'
#' The tibble includes metadata attributes:
#' \describe{
#'   \item{download_info}{List with download statistics}
#'   \item{source}{Data source used (web or cache)}
#'   \item{download_time}{Timestamp of download}
#' }
#'
#' @keywords internal
#' @importFrom cli cli_inform cli_warn cli_abort
#' @importFrom dplyr filter mutate across where select bind_rows
#' @importFrom tidyr pivot_longer separate_wider_delim
#' @importFrom parallel mclapply
#' @seealso [get_rppi()]
#' @examples \dontrun{
#' # Get all the available indices (with progress)
#' fz <- get_rppi_fipezap(quiet = FALSE)
#'
#' # Get all indices available for Porto Alegre
#' poa <- get_rppi_fipezap(city = "Porto Alegre")
#'
#' # Use cached data for faster access
#' cached_data <- get_rppi_fipezap(cached = TRUE)
#'
#' # Check download metadata
#' attr(fz, "download_info")
#' }
get_rppi_fipezap <- function(
  city = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Input validation ----
  if (!is.character(city) || length(city) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg city} parameter",
      "x" = "{.arg city} must be a single character string"
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
    if (!quiet) {
      cli::cli_inform("Loading FipeZap RPPI data from cache...")
    }

    tryCatch(
      {
        # Use new unified architecture for cached data
        df <- get_dataset("rppi", source = "github", category = "fipe")

        # Filter by city if specified
        if (city != "all" && city %in% unique(df$name_muni)) {
          df <- dplyr::filter(df, name_muni == city)
        }

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded {nrow(df)} FipeZap RPPI records from cache"
          )
        }

        # Add metadata
        attr(df, "source") <- "cache"
        attr(df, "download_time") <- Sys.time()
        attr(df, "download_info") <- list(
          city = city,
          source = "cache"
        )

        return(df)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download from FipeZap"
          ))
        }
      }
    )
  }

  # Download and process data ----
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
      max_col <- stringr::str_extract(
        stringr::str_match(range, ":[A-Z]+[0-9]"),
        "[A-Z]+")
      n1 <- stringr::str_locate(range, max_col)[, 1]
      n2 <- stringr::str_locate(range, max_col)[, 2]
      range <- paste0(
        stringr::str_sub(range, 1, n1 - 1),
        "BD",
        stringr::str_sub(range, n2 + 1, nchar(range)))
    }

    # Import Excel
    fipe <- readxl::read_excel(
      temp_path,
      sheet = x,
      skip = 4,
      col_names = fipezap_col_names(),
      range = range
    )
    # Converts all character columns to numeric
    fipe <- fipe |>
      dplyr::mutate(dplyr::across(dplyr::where(is.character), as.numeric))

    return(fipe)

  }

  # Import data from all sheets
  if (!quiet) {
    cli::cli_inform("Reading data from Excel sheets...")
  }

  fipezap <- parallel::mclapply(sheet_names, import_fipezap)
  # Names each list element using city names
  names(fipezap) <- city_names
  # Stacks all sheets together
  fipezap <- dplyr::bind_rows(fipezap, .id = "name_muni")

  if (!quiet) {
    cli::cli_inform("Processing and cleaning FipeZap data...")
  }

  # Clean data
  clean_fipe <- fipezap |>
    # Convert from wide to long
    tidyr::pivot_longer(
      cols = dplyr::where(is.numeric),
      names_to = "info",
      values_to = "value"
    ) |>
    # Split the info column to facilitate row-filtering
    tidyr::separate_wider_delim(
      cols = "info",
      names = c("market", "rent_sale", "variable", "rooms"),
      delim = "-"
    ) |>
    # Convert the date column to YMD
    dplyr::mutate(date = lubridate::ymd(date)) |>
    # Select column order
    dplyr::select(date, name_muni, market, rent_sale, variable, rooms, value)

  # Filter by city if specified
  if (city != "all" && city %in% unique(clean_fipe$name_muni)) {
    clean_fipe <- dplyr::filter(clean_fipe, name_muni == city)
  }

  # Add metadata attributes
  attr(clean_fipe, "source") <- "web"
  attr(clean_fipe, "download_time") <- Sys.time()
  attr(clean_fipe, "download_info") <- list(
    city = city,
    sheets_processed = length(sheet_names),
    source = "web"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed FipeZap RPPI data with {nrow(clean_fipe)} records")
  }

  return(clean_fipe)

}

#' Creates column names for the FipeZap spreadsheet
#'
#' @details Since all tables follow the column-name strucure, this function serves
#' as an easy wrapper to avoid import issues. Should always be used with
#' readxl::read_excel(col_names = FALSE).
#' Categories are: residential x commercial, sales x rent, and number of rooms.
#' Variables include:
#' FipeIndex (index), month on month change (chg), 12 months accumulated change (chg_12m),
#' and price/rent per squared meter (price_m2).
#' Total rooms represents a weighted average of 1, 2, 3, and 4 bedrooms indicies.
#' @noRd
fipezap_col_names <- function() {

  market <- c("residential", "commercial")
  transaction <- c("sale", "rent")
  var_sale <- c("index", "chg", "acum12m", "price_m2")
  var_rent <- c(var_sale, "yield")
  rooms <- c("total", 1:4)

  cols_sale <- paste(rep(var_sale, each = length(rooms)), rooms, sep = "-")
  cols_rent <- paste(rep(var_rent, each = length(rooms)), rooms, sep = "-")

  cols_res <- c(
    paste(market[1], transaction[1], cols_sale, sep = "-"),
    paste(market[1], transaction[2], cols_rent, sep = "-")
  )

  cols_com <- c(
    paste(market[2], transaction[1], var_sale, "total", sep = "-"),
    paste(market[2], transaction[2], var_rent, "total", sep = "-")
  )

  cols_full <- c(cols_res, cols_com)
  out <- c("date", cols_full)

  return(out)
}
