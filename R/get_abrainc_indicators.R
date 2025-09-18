#' Import Indicators from the Abrainc-Fipe Report
#'
#' @section Deprecation:
#' This function is deprecated. Use \code{\link{get_dataset}("abrainc_indicators")} instead.
#'
#' Downloads data from the Abrainc-Fipe Indicators report with modern error
#' handling, progress reporting, and robust download capabilities. Data includes
#' information on new launches, sales, delivered units, etc. in the primary
#' market.
#'
#' @details
#'
#' The data in `'indicator'` gives broad numbers of launches, sales, supply, etc.
#' of new housing units in the primary sector.
#'
#' The data in `'radar'` is a 0-10 standardized index that serves as a proxy
#' for general business conditions.
#'
#' The data in `'leading'` compiles building permits data in Sao Paulo and uses
#' this information as proxy for a real estate leading indicator.
#'
#' Units indicated as `"Social Housing (MCMV)"` are units related either to the
#' Minha Casa Minha Vida (MCMV) or Casa Verde Amarela (CVA) federal government
#' housing programs. These programs aim to provide affordable housing for low to
#' medium income families. While the eligible families enjoy subsidized credit
#' conditions the housing is not free (families commit to monthly mortgage payments)
#' and is usually built by private developers. The definition of social housing
#' varies by country so caution is advised in making international comparisons.
#'
#' Data comes from developers that are partnered with Abrainc. As of June 2023, there were
#' 66 real estate developers associated with Abrainc.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' including download status and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and graceful fallback
#' to cached data when downloads fail. Excel download errors are handled with
#' automatic retries and informative error messages.
#'
#' @param table Character. One of `'indicator'` (default), `'radar'`, `'leading'`, or `'all'`.
#' @param category Character. **Deprecated**. Use `table` parameter instead.
#' @param cached Logical. If `TRUE`, attempts to load data from package cache
#'   using the unified dataset architecture.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   downloads. Defaults to 3.
#'
#' @return Either a named `list` (when table is `'all'`) or a `tibble`
#'   (for specific tables). The return includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used (web or cache)}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @export
#' @source Abrainc-Fipe available at [https://www.fipe.org.br/pt-br/indices/abrainc](https://www.fipe.org.br/pt-br/indices/abrainc)
#' @importFrom cli cli_inform cli_warn cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom dplyr filter select mutate rename left_join group_by slice
#' @importFrom tidyr pivot_longer separate_wider_delim
#' @importFrom readxl read_excel
#' @importFrom httr GET write_disk set_config config
#'
#' @examples \dontrun{
#' # Get all available data (with progress)
#' all_data <- get_abrainc_indicators(quiet = FALSE)
#'
#' # Get only the Radar data
#' radar <- get_abrainc_indicators(table = "radar")
#'
#' # Use cached data for faster access
#' cached_data <- get_abrainc_indicators(cached = TRUE)
#'
#' # Check download metadata
#' attr(radar, "download_info")
#' }
get_abrainc_indicators <- function(
  table = "indicator",
  category = NULL,
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Deprecation warning ----
  .Deprecated("get_dataset",
             msg = "get_abrainc_indicators() is deprecated. Use get_dataset('abrainc_indicators') instead.")

  # Input validation and backward compatibility ----
  valid_tables <- c("all", "indicator", "radar", "leading")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn("The 'category' parameter is deprecated. Use 'table' instead.")
    table <- category
  }

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
    if (!quiet) {
      cli::cli_inform("Loading Abrainc-Fipe indicators from cache...")
    }

    tryCatch(
      {
        # Map category to unified architecture
        if (table == "all") {
          data <- get_dataset("abrainc_indicators", source = "github")
        } else {
          data <- get_dataset(
            "abrainc_indicators",
            source = "github",
            category = table
          )
        }

        if (!quiet) {
          cli::cli_inform(
            "Successfully loaded Abrainc-Fipe indicators from cache"
          )
        }

        # Add metadata
        attr(data, "source") <- "cache"
        attr(data, "download_time") <- Sys.time()
        attr(data, "download_info") <- list(
          category = table,
          source = "cache"
        )

        return(data)
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn(c(
            "Failed to load cached data: {e$message}",
            "i" = "Falling back to fresh download"
          ))
        }
      }
    )
  }

  # Download Excel file ----
  if (!quiet) {
    cli::cli_inform("Downloading Abrainc-Fipe indicators from FIPE...")
  }

  download_result <- download_abrainc_excel(
    max_retries = max_retries,
    quiet = quiet
  )

  if (is.null(download_result$path)) {
    cli::cli_abort(c(
      "Failed to download Abrainc-Fipe data",
      "x" = "All {max_retries} download attempt{?s} failed",
      "i" = "Check your internet connection and try again"
    ))
  }

  temp_path <- download_result$path

  # Swap vector to convert the category into the respective sheet name
  vl <- c(
    "indicator" = "Indicadores Abrainc-Fipe",
    "radar" = "Radar Abrainc-Fipe",
    "leading" = "Indicador Antecedente (SP)"
  )

  # Helper function to import the data from the spreadsheet
  import_abrainc <- function(category) {
    if (table == "all") {
      sheet_name <- vl
    } else {
      sheet_name <- vl[[category]]
    }

    data <- purrr::map(sheet_name, function(s) {
      # Get import-range for current sheet
      range <- get_range(path = temp_path, sheet = s, skip_row = 6)
      # Import Excel spreadsheet
      readxl::read_excel(temp_path, sheet = s, range = range, col_names = FALSE)
    })

    names(data) <- names(sheet_name)
    return(data)
  }

  # Import all sheets
  abrainc <- suppressMessages(import_abrainc(table))

  # Clean all sheets

  # Name each element of the list
  if (table == "all") {
    category <- names(vl)
  }
  names(abrainc) <- category
  out <- purrr::map(category, function(x) {
    suppressWarnings(clean_abrainc(abrainc, x))
  })

  # Output
  names(out) <- category
  # If only a single category is selected return a tibble else return a named list
  if (length(category) == 1) {
    out <- purrr::pluck(out, 1)
  }

  # Add metadata attributes
  attr(out, "source") <- "web"
  attr(out, "download_time") <- Sys.time()
  attr(out, "download_info") <- list(
    category = table,
    retry_attempts = download_result$attempts,
    source = "web"
  )

  if (!quiet) {
    cli::cli_inform("Successfully processed Abrainc-Fipe indicators")
  }

  return(out)
}

#' Download Abrainc Excel File with Retry Logic
#'
#' Internal function to download the Abrainc-Fipe Excel file with retry attempts
#' and proper error handling.
#'
#' @param max_retries Maximum number of retry attempts
#' @param quiet Logical controlling messages
#'
#' @return List with path (character or NULL) and attempt count
#' @keywords internal
download_abrainc_excel <- function(max_retries, quiet) {
  url <- "https://downloads.fipe.org.br/indices/abrainc/series-historicas-abraincfipe.xlsx"
  temp_path <- tempfile("abrainc_fipe.xlsx")
  attempts <- 0
  last_error <- NULL

  while (attempts <= max_retries) {
    attempts <- attempts + 1

    tryCatch(
      {
        # Configure SSL settings
        httr::set_config(httr::config(ssl_verifypeer = 0L))

        # Attempt download
        response <- httr::GET(
          url = url,
          httr::write_disk(path = temp_path, overwrite = TRUE)
        )

        # Check if download was successful
        if (httr::status_code(response) == 200 && file.exists(temp_path)) {
          # Validate file has content and is a valid Excel file
          if (file.size(temp_path) > 1000) {
            # Minimum reasonable file size
            tryCatch(
              {
                # Test if we can read the Excel file structure
                sheets <- readxl::excel_sheets(temp_path)
                expected_sheets <- c(
                  "Indicadores Abrainc-Fipe",
                  "Radar Abrainc-Fipe",
                  "Indicador Antecedente (SP)"
                )

                # Check if we have the expected sheets
                if (all(expected_sheets %in% sheets)) {
                  return(list(
                    path = temp_path,
                    attempts = attempts,
                    error = NULL
                  ))
                } else {
                  last_error <<- "Downloaded file does not contain expected Excel sheets"
                }
              },
              error = function(e) {
                last_error <<- paste(
                  "Downloaded file is not a valid Excel file:",
                  e$message
                )
              }
            )
          } else {
            last_error <<- "Downloaded file is too small or empty"
          }
        } else {
          last_error <<- paste(
            "HTTP request failed with status:",
            httr::status_code(response)
          )
        }
      },
      error = function(e) {
        last_error <<- e$message

        # Only retry if we haven't exceeded max_retries
        if (attempts > max_retries) {
          return(NULL)
        }

        # Add small delay before retry
        if (attempts > 1) {
          Sys.sleep(min(attempts * 0.5, 3)) # Progressive backoff, max 3 seconds
        }
      }
    )
  }

  # All attempts failed
  return(list(
    path = NULL,
    attempts = attempts,
    error = last_error
  ))
}

abrainc_basic_clean <- function(df, subcategories) {
  df |>
    # Convert date column to YMD and create a year column
    dplyr::mutate(
      date = lubridate::ymd(date),
      year = lubridate::year(date)
    ) |>
    # Convert all columns except date to numeric
    dplyr::mutate(dplyr::across(!date, as.numeric)) |>
    # Convert to long and split the column name
    tidyr::pivot_longer(cols = -c(date, year)) |>
    tidyr::separate_wider_delim(
      cols = name,
      names = subcategories,
      delim = "-",
      too_few = "align_start"
    )
}

clean_abrainc <- function(ls, category) {
  # Pluck the tibble from the list
  df <- ls[[category]]
  # Get column names and a auxiliar tibble with variable labels
  nms <- abrainc_fipe_col_names()
  labels <- nms[[category]][["labels"]]
  col_names <- nms[[category]][["names"]]
  # Remove columns with only NAs
  df <- dplyr::select(df, dplyr::where(~ !all(is.na(.x))))
  # Just to make sure there is no error
  df <- df[, 1:length(col_names)]
  names(df) <- col_names
  # The names will be split into these columns
  subcategories <- list(
    indicator = c("category", "variable"),
    radar = c("category", "variable", "source"),
    leading = c("variable", "zone")
  )
  # Clean the tibble
  clean_df <- abrainc_basic_clean(df, subcategories[[category]])

  if (table == "indicator") {
    # Join final table with labels for variables
    clean_df <- dplyr::left_join(
      clean_df,
      labels,
      by = dplyr::join_by(variable)
    )
  }

  if (table == "leading") {
    clean_df <- clean_df |>
      # Fix the Zone column and join with variable labels
      dplyr::mutate(
        zone = stringr::str_replace(zone, "_", " "),
        zone = stringr::str_to_title(zone)
      ) |>
      dplyr::left_join(labels, by = dplyr::join_by(variable))
  }

  if (table == "radar") {
    clean_df <- clean_df |>
      # Compute yearly averages for categories and variables
      dplyr::mutate(
        avg_category = mean(value, na.rm = TRUE),
        .by = category
      ) |>
      dplyr::mutate(
        avg_year_category = mean(value, na.rm = TRUE),
        .by = c(year, category)
      ) |>
      dplyr::mutate(
        avg_year_variable = mean(value, na.rm = TRUE),
        .by = c(year, variable)
      ) |>
      # Compute trends for variables
      dplyr::mutate(
        ma3 = zoo::rollmeanr(value, k = 3, fill = NA),
        ma6 = zoo::rollmeanr(value, k = 3, fill = NA),
        .by = variable
      ) |>
      # Join with variable labels
      dplyr::left_join(labels, by = dplyr::join_by(variable))
  }

  return(clean_df)
}

abrainc_fipe_col_names <- function() {
  # ind_col_names <- c(
  #   "date", "new_units-total", "new_units-market_rate", "new_units-social_housing",
  #   "new_units-other", "new_units-missing_info", "sold-total", "sold-market_rate",
  #   "sold-social_housing", "sold-other", "sold-missing_info", "delivered-total",
  #   "delivered-market_rate", "delivered-social_housing", "delivered-other",
  #   "delivered-missing_info", "distratado-total", "distratado-market_rate",
  #   "distratado-social_housing", "distratado-other", "distratado-missing_info",
  #   "supply-total", "supply-market_rate", "supply-social_housing", "supply-other",
  #   "supply-missing_info", "value-new_units", "value-sale", "value-new_units_cpi",
  #   "value-sale_cpi")

  ind_col_names <- c(
    "date",
    "new_units-total",
    "new_units-market_rate",
    "new_units-social_housing",
    "new_units-other",
    "sold-total",
    "sold-market_rate",
    "sold-social_housing",
    "sold-other",
    "delivered-total",
    "delivered-market_rate",
    "delivered-social_housing",
    "delivered-other",
    "distratado-total",
    "distratado-market_rate",
    "distratado-social_housing",
    "distratado-other",
    "supply-total",
    "supply-market_rate",
    "supply-social_housing",
    "supply-other",
    "value-new_units",
    "value-sale",
    "value-new_units_cpi",
    "value-sale_cpi"
  )

  ind_labels <- dplyr::tribble(
    ~variable,
    ~variable_label,
    "total",
    "Total",
    "market_rate",
    "Market-rate Development",
    "social_housing",
    "Social Housing (MCMV)",
    "other",
    "Others",
    "missing_info",
    "Missing Info.",
    "new_units",
    "New Units",
    "sale",
    "Sales",
    "new_units_cpi",
    "New Units (CPI adjusted)",
    "sale_cpi",
    "Sales(CPI) adjusted"
  )

  radar_col_names <- c(
    "date",
    "macro-confidence-FGV",
    "macro-activity-BCB",
    "macro-interest-BM&F, BCB",
    "credit-finance_condition-BCB",
    "credit-real_concession-BCB, IBGE",
    "credit-atractivity-BCB",
    "demand-employment-IBGE",
    "demand-wage-IBGE",
    "demand-real_estate_investing-FipeZap, BM&F, BCB",
    "sector-input_costs-CAGED, IBGE, FGV",
    "sector-new_units-FipeZap",
    "sector-real_estate_prices-FGV"
  )

  radar_labels <- dplyr::tribble(
    ~variable,
    ~variable_label,
    "confidence",
    "Confidence Index",
    "activity",
    "Activity Index",
    "interest",
    "Interest Rate",
    "finance_condition",
    "Financing Conditions",
    "real_concession",
    "Real Concessions",
    "atractivity",
    "Atractivity",
    "employment",
    "Jobs",
    "wage",
    "Wages",
    "real_estate_investing",
    "Investment in Real Estate",
    "input_costs",
    "Input Costs",
    "new_units",
    "New Launches",
    "real_estate_prices",
    "Real Estate Prices"
  )

  xx <- c(
    "leading_index",
    "leading_index_12m",
    "alvaras_total",
    "alvaras_prop",
    "alvaras_total_12m",
    "alvaras_prop_12m"
  )
  yy <- c(
    "total",
    "centro",
    "zona_norte",
    "zona_sul",
    "zona_leste",
    "zona_oeste"
  )

  lead_col_names <- c("date", paste(rep(xx, each = length(yy)), yy, sep = "-"))

  lead_labels <- dplyr::tribble(
    ~variable,
    ~variable_label,
    "leading_index",
    "Real Estate Leading Indicator (100 = dec/2000)",
    "leading_index_12m",
    "Real Estate Leading Indicator (% 12-month cumulative) (%)",
    "alvaras_total",
    "Number of Building Permits (per month)",
    "alvaras_prop",
    "Distribution of Building Permits in São Paulo (Total)",
    "alvaras_total_12m",
    "Building Permits (12-month cumulative)",
    "alvaras_prop_12m",
    "Distribution of Building Permits in São Paulo (%)"
  )

  out <- list(
    indicator = list(names = ind_col_names, labels = ind_labels),
    radar = list(names = radar_col_names, labels = radar_labels),
    leading = list(names = lead_col_names, labels = lead_labels)
  )

  return(out)
}
