#' Import Indicators from the Abrainc-Fipe Report
#'
#' Downloads data from the Abrainc-Fipe Indicators report. Data includes
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
#' @param category One of `'all'` (default), `'indicator'`, `'radar'`, or
#' `'leading'`.
#' @inheritParams get_secovi
#'
#' @return A named `list` or a `tibble` containing updated data of the Abrainc Fipe
#' Indicators.
#' @export
#' @source Abrainc-Fipe available at [https://www.fipe.org.br/pt-br/indices/abrainc](https://www.fipe.org.br/pt-br/indices/abrainc)
#'
#' @examples \dontrun{
#' # Get only the Radar data
#' radar <- get_abrainc_indicators(category = "radar")
#' # Get all available data
#' abrainc <- get_abrainc_indicators()
#' }
get_abrainc_indicators <- function(category = "all", cached = FALSE) {

  # Check category param
  stopifnot(
    "Category must be one of 'all', 'indicator', 'radar', or 'leading'." =
    any(category %in% c("all", "indicator", "radar", "leading"))
    )

  # Download cached data from the GitHub repository
  if (cached) {
    abrainc <- import_cached("abrainc")
    if (category == "all") {
      return(abrainc)
    } else {
      return(abrainc[[category]])
    }
  }

  # Url to excel spreadsheet
  url <- "https://downloads.fipe.org.br/indices/abrainc/series-historicas-abraincfipe.xlsx"
  # Define output path file
  temp_path <- tempfile("abrainc_fipe.xlsx")
  # Download the Excel spreadsheet
  httr::set_config(httr::config(ssl_verifypeer = 0L))
  httr::GET(url = url,httr::write_disk(path = temp_path, overwrite = TRUE))

  # Swap vector to convert the category into the respective sheet name
  vl <- c(
    "indicator" = "Indicadores Abrainc-Fipe",
    "radar" = "Radar Abrainc-Fipe",
    "leading" = "Indicador Antecedente (SP)"
  )

  # Helper function to import the data from the spreadsheet
  import_abrainc <- function(category) {

    if (category == "all") {
      sheet_name <- vl
    } else {
      sheet_name <- vl[[category]]
    }

    data <- purrr::map(sheet_name, \(s) {
      # Get import-range for current sheet
      range <- get_range(path = temp_path, sheet = s, skip_row = 6)
      # Import Excel spreadsheet
      readxl::read_excel(temp_path, sheet = s, range = range, col_names = FALSE)
    })

    names(data) <- names(sheet_name)
    return(data)

  }

  # Import all sheets
  abrainc <- suppressMessages(import_abrainc(category))

  # Clean all sheets

  # Name each element of the list
  if (category == "all") {
    category <- names(vl)
  }
  names(abrainc) <- category
  out <- purrr::map(category, \(x) suppressWarnings(clean_abrainc(abrainc, x)))

  # Output
  names(out) <- category
  # If only a single category is selected return a tibble else return a named list
  if (length(category) == 1) {
    out <- purrr::pluck(out, 1)
  }

  return(out)

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
  df <- dplyr::select(df, dplyr::where(~!all(is.na(.x))))
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

  if (category == "indicator") {
    # Join final table with labels for variables
    clean_df <- dplyr::left_join(clean_df, labels, by = "variable")
  }

  if (category == "leading") {

    clean_df <- clean_df |>
      # Fix the Zone column and join with variable labels
      dplyr::mutate(
        zone = stringr::str_replace(zone, "_", " "),
        zone = stringr::str_to_title(zone)
      ) |>
      dplyr::left_join(labels, by = "variable")
  }

  if (category == "radar") {

    clean_df <- clean_df |>
      # Compute yearly averages for categories and variables
      dplyr::group_by(category) |>
      dplyr::mutate(avg_category = mean(value, na.rm = T)) |>
      dplyr::group_by(year, category) |>
      dplyr::mutate(avg_year_category = mean(value, na.rm = T)) |>
      dplyr::group_by(year, variable) |>
      dplyr::mutate(avg_year_variable = mean(value, na.rm = T)) |>
      # Compute trends for variables
      dplyr::group_by(variable) |>
      dplyr::mutate(
        ma3 = zoo::rollmeanr(value, k = 3, fill = NA),
        ma6 = zoo::rollmeanr(value, k = 3, fill = NA)
        ) |>
      dplyr::ungroup() |>
      # Join with variable labels
      dplyr::left_join(labels, by = "variable")

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
    "new_units-total", "new_units-market_rate", "new_units-social_housing", "new_units-other",
    "sold-total", "sold-market_rate", "sold-social_housing", "sold-other",
    "delivered-total", "delivered-market_rate", "delivered-social_housing", "delivered-other",
    "distratado-total", "distratado-market_rate", "distratado-social_housing", "distratado-other",
    "supply-total", "supply-market_rate", "supply-social_housing", "supply-other",
    "value-new_units", "value-sale", "value-new_units_cpi", "value-sale_cpi")

  ind_labels <- tibble::tribble(
          ~variable,            ~variable_label,
            "total",                    "Total",
      "market_rate",  "Market-rate Development",
   "social_housing",    "Social Housing (MCMV)",
            "other",                   "Others",
     "missing_info",            "Missing Info.",
        "new_units",                "New Units",
             "sale",                    "Sales",
    "new_units_cpi", "New Units (CPI adjusted)",
         "sale_cpi",      "Sales(CPI) adjusted"
  )

  radar_col_names <- c(
    "date", "macro-confidence-FGV", "macro-activity-BCB", "macro-interest-BM&F, BCB",
    "credit-finance_condition-BCB", "credit-real_concession-BCB, IBGE",
    "credit-atractivity-BCB", "demand-employment-IBGE", "demand-wage-IBGE",
    "demand-real_estate_investing-FipeZap, BM&F, BCB",
    "sector-input_costs-CAGED, IBGE, FGV", "sector-new_units-FipeZap",
    "sector-real_estate_prices-FGV")

  radar_labels <- tibble::tribble(
                  ~variable,             ~variable_label,
               "confidence",          "Confidence Index",
                 "activity",            "Activity Index",
                 "interest",             "Interest Rate",
        "finance_condition",      "Financing Conditions",
          "real_concession",          "Real Concessions",
              "atractivity",               "Atractivity",
               "employment",                      "Jobs",
                     "wage",                     "Wages",
    "real_estate_investing", "Investment in Real Estate",
              "input_costs",               "Input Costs",
                "new_units",              "New Launches",
       "real_estate_prices",        "Real Estate Prices"
  )

  xx <- c("leading_index", "leading_index_12m", "alvaras_total", "alvaras_prop",
          "alvaras_total_12m", "alvaras_prop_12m")
  yy <- c("total", "centro", "zona_norte", "zona_sul", "zona_leste", "zona_oeste")

  lead_col_names <- c("date", paste(rep(xx, each = length(yy)), yy, sep = "-"))

  lead_labels <- tibble::tribble(
    ~variable,                                             ~variable_label,
    "leading_index",            "Real Estate Leading Indicator (100 = dec/2000)",
    "leading_index_12m", "Real Estate Leading Indicator (% 12-month cumulative) (%)",
    "alvaras_total",                    "Number of Building Permits (per month)",
    "alvaras_prop",     "Distribution of Building Permits in São Paulo (Total)",
    "alvaras_total_12m",                    "Building Permits (12-month cumulative)",
    "alvaras_prop_12m",         "Distribution of Building Permits in São Paulo (%)"
  )

  out <- list(
    indicator = list(names = ind_col_names, labels = ind_labels),
    radar = list(names = radar_col_names, labels = radar_labels),
    leading = list(names = lead_col_names, labels = lead_labels)
  )

  return(out)

}
