#' Get Residential Property Price Indices from BIS
#'
#' @description
#' Downloads Residential Property Price Indices from BIS with support for
#' selected series and detailed monthly/quarterly/annual/halfyearly datasets.
#'
#' @param table Character. Dataset table: "selected", "detailed_monthly",
#'   "detailed_quarterly", "detailed_annual", or "detailed_halfyearly".
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Tibble with BIS RPPI data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source Bank for International Settlements (BIS) Residential Property Prices
#' @keywords internal
get_rppi_bis <- function(
  table = "selected",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c(
    "selected",
    "detailed_monthly",
    "detailed_quarterly",
    "detailed_annual",
    "detailed_halfyearly"
  )

  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = FALSE
  )

  cli_user("Downloading BIS RPPI data for table '{table}'", quiet = quiet)

  if (table == "selected") {
    csv_path <- download_bis_selected(quiet = quiet, max_retries = max_retries)
    df <- clean_bis_selected(csv_path, quiet)
  } else {
    csv_path <- download_bis_detailed(quiet = quiet, max_retries = max_retries)
    detailed_data <- clean_bis_detailed(csv_path, quiet)

    df <- switch(
      table,
      "detailed_monthly" = detailed_data[["monthly"]],
      "detailed_quarterly" = detailed_data[["quarterly"]],
      "detailed_annual" = detailed_data[["annual"]],
      "detailed_halfyearly" = detailed_data[["halfyearly"]],
      cli::cli_abort("Unknown detailed table: {.val {table}}")
    )

    if (is.null(df)) {
      cli::cli_abort(
        "Failed to extract table {.val {table}} from detailed data"
      )
    }
  }

  df <- attach_dataset_metadata(df, source = "web", category = table)

  cli_user("BIS RPPI data retrieved: {nrow(df)} records", quiet = quiet)

  return(df)
}

# Download BIS Selected -------------------------------------------------------

#' Download BIS RPPI Selected ZIP
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to extracted CSV file
#' @keywords internal
download_bis_selected <- function(quiet, max_retries) {
  cli_debug("Downloading BIS selected RPPI ZIP file...")
  csv_path <- download_zip(
    url = "https://data.bis.org/static/bulk/WS_SPP_csv_col.zip",
    file_pattern = "\\.csv$",
    min_size = 1000,
    max_retries = max_retries,
    quiet = quiet
  )
  return(csv_path)
}

# Clean BIS Selected ----------------------------------------------------------

#' Clean BIS Selected CSV Data
#'
#' Reads the column-oriented CSV from the BIS SPP dataset, pivots date columns
#' to long format, and standardises column names.
#'
#' @param csv_path Path to the extracted CSV file
#' @param quiet Logical controlling messages
#'
#' @return Processed BIS selected data tibble
#' @keywords internal
clean_bis_selected <- function(csv_path, quiet) {
  cli_debug("Processing BIS selected RPPI data...")

  raw <- readr::read_csv(csv_path, show_col_types = FALSE)

  # Date columns are named like "2005-Q1", "2005-Q2", etc.
  col_names <- names(raw)
  date_cols <- col_names[stringr::str_detect(col_names, "^[0-9]{4}")]

  long <- raw |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(date_cols),
      names_to = "date",
      values_to = "value"
    ) |>
    dplyr::mutate(
      date = zoo::as.yearqtr(date, format = "%Y-Q%q"),
      date = zoo::as.Date(date)
    )

  cols_rename <- c(
    "freq_code" = "FREQ",
    "frequency" = "Frequency",
    "ref_area_code" = "REF_AREA",
    "ref_area_name" = "Reference area",
    "unit_value_code" = "VALUE",
    "unit_value" = "Value",
    "unit_code" = "UNIT_MEASURE",
    "unit_name" = "Unit of measure",
    "series_code" = "Series"
  )

  cols_select <- c(
    "date",
    "ref_area_code",
    "ref_area_name",
    "unit",
    "unit_name",
    "is_nominal",
    "series_code",
    "value"
  )

  cli_debug("Cleaning BIS selected data...")

  clean <- long |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::select(dplyr::where(\(x) !all(is.na(x)))) |>
    dplyr::mutate(
      unit = dplyr::if_else(unit_code == 771, "yoy_chg", "index"),
      is_nominal = as.integer(dplyr::if_else(unit_value_code == "R", 0L, 1L))
    ) |>
    dplyr::select(dplyr::all_of(cols_select))

  return(clean)
}

# Download BIS Detailed -------------------------------------------------------

#' Download BIS RPPI Detailed ZIP
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#'
#' @return Path to extracted CSV file
#' @keywords internal
download_bis_detailed <- function(quiet, max_retries) {
  cli_debug("Downloading BIS detailed RPPI ZIP file...")
  csv_path <- download_zip(
    url = "https://data.bis.org/static/bulk/WS_DPP_csv_flat.zip",
    file_pattern = "\\.csv$",
    min_size = 1000,
    max_retries = max_retries,
    quiet = quiet
  )
  return(csv_path)
}

# Read BIS Detailed CSV -------------------------------------------------------

#' Read and Clean BIS Detailed CSV
#'
#' Reads the flat CSV, applies `clean_names()` once, and drops all-NA columns.
#'
#' @param csv_path Path to the extracted CSV file
#'
#' @return Cleaned tibble
#' @keywords internal
#' @noRd
read_bis_detailed_csv <- function(csv_path) {
  raw <- readr::read_csv(
    csv_path,
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE
  )

  clean <- raw |>
    janitor::clean_names() |>
    dplyr::select(dplyr::where(\(x) !all(is.na(x))))

  return(clean)
}

# Parse BIS Detailed Columns --------------------------------------------------

#' Parse BIS Detailed Columns
#'
#' Splits compound columns (e.g. "AE: United Arab Emirates") into separate
#' code and name columns using a data-driven configuration.
#'
#' @param data Tibble from `read_bis_detailed_csv()`
#'
#' @return Tibble with split columns
#' @keywords internal
#' @noRd
parse_bis_detailed_columns <- function(data) {
  cols_to_split <- list(
    structure_id = c("series_code", "series_name"),
    freq_frequency = c("freq_code", "freq_name"),
    ref_area_reference_area = c("ref_area_code", "ref_area_name"),
    covered_area_covered_area = c("covered_area_code", "covered_area_name"),
    re_type_real_estate_type = c("re_type_code", "re_type_name"),
    re_vintage_real_estate_vintage = c("re_vintage_code", "re_vintage_name"),
    compiling_org_compiling_agency = c(
      "compiling_org_code",
      "compiling_org_name"
    ),
    priced_unit_priced_unit = c("priced_unit_code", "priced_unit_name"),
    adjust_coded_seasonal_adjustment = c(
      "seas_adjust_code",
      "seas_adjust_name"
    ),
    availability_availability = c("availability_code", "availability_name"),
    unit_measure_unit_of_measure = c("unit_code", "unit_name"),
    unit_mult_unit_multiplier = c("unit_mult_code", "unit_mult_name")
  )

  result <- purrr::reduce(
    names(cols_to_split),
    function(df, col) {
      if (!col %in% names(df)) {
        return(df)
      }
      tidyr::separate_wider_delim(
        df,
        cols = dplyr::all_of(col),
        delim = ": ",
        names = cols_to_split[[col]],
        too_many = "drop",
        too_few = "align_start"
      )
    },
    .init = data
  )

  if ("obs_value_observation_value" %in% names(result)) {
    result <- dplyr::rename(result, value = obs_value_observation_value)
  }

  return(result)
}

# Date parsers for BIS detailed frequencies -----------------------------------

#' @keywords internal
#' @noRd
parse_bis_annual_date <- function(df) {
  dplyr::mutate(
    df,
    date = lubridate::make_date(time_period_time_period_or_range, 1, 1),
    year = as.integer(time_period_time_period_or_range),
    .before = 1
  )
}

#' @keywords internal
#' @noRd
parse_bis_monthly_date <- function(df) {
  dplyr::mutate(
    df,
    date = lubridate::ymd(paste0(time_period_time_period_or_range, "-01")),
    year = lubridate::year(date),
    month = lubridate::month(date),
    .before = 1
  )
}

#' @keywords internal
#' @noRd
parse_bis_quarterly_date <- function(df) {
  dplyr::mutate(
    df,
    date = zoo::as.Date(zoo::as.yearqtr(
      time_period_time_period_or_range,
      format = "%Y-Q%q"
    )),
    year = lubridate::year(date),
    quarter = lubridate::quarter(date),
    .before = 1
  )
}

#' @keywords internal
#' @noRd
parse_bis_halfyearly_date <- function(df) {
  result <- df |>
    dplyr::rename(time = time_period_time_period_or_range) |>
    dplyr::mutate(
      date = dplyr::if_else(
        stringr::str_detect(time, "S1$"),
        lubridate::make_date(stringr::str_sub(time, 1, 4), 1, 1),
        lubridate::make_date(stringr::str_sub(time, 1, 4), 7, 1)
      ),
      year = lubridate::year(date),
      semester = lubridate::semester(date),
      .before = 1
    )
  return(result)
}

# Clean BIS Frequency ---------------------------------------------------------

#' Process a Single BIS Frequency Subset
#'
#' Filters the parsed detailed data to a single frequency, applies a
#' date-parsing function, drops metadata columns, and converts selected
#' code columns to integer.
#'
#' @param data Full parsed detailed tibble
#' @param freq_filter Frequency label to filter on (e.g. "Annual", "Monthly")
#' @param parse_date_fn Function that receives filtered tibble and returns it
#'   with `date` (and optional time-period columns like year, month) added
#' @param drop_cols Character vector of columns to drop for this frequency
#' @param num_code_cols Character vector of `*_code` columns to convert to
#'   integer for this frequency
#'
#' @return Processed tibble for the given frequency
#' @keywords internal
#' @noRd
clean_bis_frequency <- function(
  data,
  freq_filter,
  parse_date_fn,
  drop_cols,
  num_code_cols = character()
) {
  result <- data |>
    dplyr::filter(freq_name == freq_filter) |>
    dplyr::select(dplyr::where(\(x) !all(is.na(x))))

  result <- parse_date_fn(result)

  result <- result |>
    dplyr::select(-dplyr::any_of(drop_cols))

  if (length(num_code_cols) > 0) {
    result <- result |>
      dplyr::mutate(dplyr::across(dplyr::all_of(num_code_cols), as.integer))
  }

  return(result)
}

# Clean BIS Detailed ----------------------------------------------------------

#' Process BIS Detailed CSV Data
#'
#' Reads the flat CSV, parses compound columns, then splits by frequency
#' with appropriate date parsing for each.
#'
#' @param csv_path Path to the extracted CSV file
#' @param quiet Logical controlling messages
#'
#' @return Named list with elements: monthly, quarterly, annual, halfyearly
#' @keywords internal
clean_bis_detailed <- function(csv_path, quiet) {
  raw <- read_bis_detailed_csv(csv_path)
  parsed <- parse_bis_detailed_columns(raw)
  parsed <- dplyr::mutate(parsed, value = as.numeric(value))

  cli_debug("Splitting BIS detailed data by frequency...")

  # Per-frequency columns to drop ----
  # Each frequency keeps different metadata columns so they cannot be merged.
  drop_cols_annual <- c(
    "time_period_time_period_or_range",
    "series_name",
    "structure",
    "action",
    "freq_code",
    "freq_name",
    "obs_conf_observation_confidentiality",
    "obs_status_observation_status",
    "seas_adjust_code",
    "seas_adjust_name"
  )

  drop_cols_monthly <- c(
    "time_period_time_period_or_range",
    "series_name",
    "structure",
    "action",
    "freq_code",
    "freq_name",
    "obs_conf_observation_confidentiality"
  )

  drop_cols_quarterly <- c(
    "time_period_time_period_or_range",
    "series_name",
    "structure",
    "action",
    "freq_code",
    "freq_name",
    "obs_conf_observation_confidentiality"
  )

  drop_cols_halfyearly <- c(
    "time",
    "series_name",
    "structure",
    "action",
    "freq_code",
    "freq_name",
    "obs_conf_observation_confidentiality"
  )

  # Per-frequency code columns to convert to integer ----
  num_cols_annual <- c(
    "re_vintage_code",
    "compiling_org_code",
    "priced_unit_code"
  )

  num_cols_monthly <- c(
    "covered_area_code",
    "re_vintage_code",
    "compiling_org_code",
    "priced_unit_code",
    "seas_adjust_code"
  )

  num_cols_quarterly <- c(
    "re_vintage_code",
    "compiling_org_code",
    "priced_unit_code",
    "seas_adjust_code"
  )

  num_cols_halfyearly <- c(
    "re_vintage_code",
    "compiling_org_code",
    "priced_unit_code",
    "seas_adjust_code"
  )

  return(list(
    monthly = clean_bis_frequency(
      parsed,
      "Monthly",
      parse_bis_monthly_date,
      drop_cols_monthly,
      num_cols_monthly
    ),
    quarterly = clean_bis_frequency(
      parsed,
      "Quarterly",
      parse_bis_quarterly_date,
      drop_cols_quarterly,
      num_cols_quarterly
    ),
    annual = clean_bis_frequency(
      parsed,
      "Annual",
      parse_bis_annual_date,
      drop_cols_annual,
      num_cols_annual
    ),
    halfyearly = clean_bis_frequency(
      parsed,
      "Half-yearly",
      parse_bis_halfyearly_date,
      drop_cols_halfyearly,
      num_cols_halfyearly
    )
  ))
}
