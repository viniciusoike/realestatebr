#' Import Indicators from the Abrainc-Fipe Report
#'
#' @details
#' Downloads data from the Abrainc-Fipe Indicators report including information on
#' new launches, sales, delivered units, and market indicators.
#'
#' @param table Character. One of `'indicator'` (default), `'radar'`, `'leading'`, or `'all'`.
#' @param quiet Logical. If `TRUE`, suppresses progress messages and warnings.
#'   If `FALSE` (default), provides detailed progress reporting.
#' @param max_retries Integer. Maximum number of retry attempts for failed
#'   downloads. Defaults to 3.
#'
#' @return Either a named `list` (when table is `'all'`) or a `tibble`
#'   (for specific tables). The return includes metadata attributes:
#'   \describe{
#'     \item{download_info}{List with download statistics}
#'     \item{source}{Data source used}
#'     \item{download_time}{Timestamp of download}
#'   }
#'
#' @source Abrainc-Fipe Indicators (FIPE)
#' @importFrom cli cli_inform
#' @importFrom dplyr select mutate left_join where join_by across
#' @importFrom tidyr pivot_longer separate_wider_delim
#' @importFrom readxl read_excel
#' @importFrom purrr map pluck
#' @importFrom lubridate ymd year
#' @importFrom stringr str_replace str_to_title
#' @keywords internal
get_abrainc_indicators <- function(
  table = "indicator",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("all", "indicator", "radar", "leading")
  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  if (!quiet) {
    cli::cli_inform("Downloading Abrainc-Fipe indicators from FIPE...")
  }

  url <- "https://downloads.fipe.org.br/indices/abrainc/series-historicas-abraincfipe.xlsx"
  expected_sheets <- c(
    "Indicadores Abrainc-Fipe",
    "Radar Abrainc-Fipe",
    "Indicador Antecedente (SP)"
  )

  temp_path <- download_excel(
    url = url,
    expected_sheets = expected_sheets,
    min_size = 1000,
    ssl_verify = FALSE, # FIPE has SSL certificate issues
    max_retries = max_retries,
    quiet = quiet
  )

  # Map category names to sheet names ----
  vl <- c(
    "indicator" = "Indicadores Abrainc-Fipe",
    "radar" = "Radar Abrainc-Fipe",
    "leading" = "Indicador Antecedente (SP)"
  )

  if (table == "all") {
    sheet_names <- vl
    category <- names(vl)
  } else {
    sheet_names <- vl[table]
    category <- table
  }

  # Import sheets ----
  abrainc <- suppressMessages(
    purrr::map(sheet_names, function(s) {
      range <- get_range(path = temp_path, sheet = s, skip_row = 6)
      readxl::read_excel(temp_path, sheet = s, range = range, col_names = FALSE)
    })
  )
  names(abrainc) <- category

  # Clean sheets ----
  out <- purrr::map(category, function(x) {
    suppressWarnings(clean_abrainc(abrainc, x))
  })
  names(out) <- category

  if (length(category) == 1) {
    out <- purrr::pluck(out, 1)
  }

  out <- attach_dataset_metadata(out, source = "web", category = table)

  if (!quiet) {
    cli::cli_inform("Successfully processed Abrainc-Fipe indicators")
  }

  return(out)
}

abrainc_basic_clean <- function(df, subcategories) {
  df |>
    dplyr::mutate(
      date = lubridate::ymd(date),
      year = lubridate::year(date)
    ) |>
    dplyr::mutate(dplyr::across(!date, as.numeric)) |>
    tidyr::pivot_longer(cols = -c(date, year)) |>
    tidyr::separate_wider_delim(
      cols = name,
      names = subcategories,
      delim = "-",
      too_few = "align_start"
    )
}

clean_abrainc <- function(ls, category) {
  df <- ls[[category]]
  nms <- build_abrainc_col_names()
  labels <- nms[[category]][["labels"]]
  col_names <- nms[[category]][["names"]]

  df <- dplyr::select(df, dplyr::where(~ !all(is.na(.x))))
  df <- df[, 1:length(col_names)]
  names(df) <- col_names

  subcategories <- list(
    indicator = c("category", "variable"),
    radar = c("category", "variable", "source"),
    leading = c("variable", "zone")
  )

  clean_df <- abrainc_basic_clean(df, subcategories[[category]])

  if (category == "indicator") {
    clean_df <- dplyr::left_join(
      clean_df,
      labels,
      by = dplyr::join_by(variable)
    )
  }

  if (category == "leading") {
    clean_df <- clean_df |>
      dplyr::mutate(
        zone = stringr::str_replace(zone, "_", " "),
        zone = stringr::str_to_title(zone)
      ) |>
      dplyr::left_join(labels, by = dplyr::join_by(variable))
  }

  if (category == "radar") {
    clean_df <- clean_df |>
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
      dplyr::mutate(
        ma3 = as.numeric(stats::filter(value, rep(1 / 3, 3), sides = 1)),
        ma6 = as.numeric(stats::filter(value, rep(1 / 6, 6), sides = 1)),
        .by = variable
      ) |>
      dplyr::left_join(labels, by = dplyr::join_by(variable))
  }

  return(clean_df)
}

build_abrainc_col_names <- function() {
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
    ~variable                  ,
    ~variable_label            ,
    "total"                    ,
    "Total"                    ,
    "market_rate"              ,
    "Market-rate Development"  ,
    "social_housing"           ,
    "Social Housing (MCMV)"    ,
    "other"                    ,
    "Others"                   ,
    "missing_info"             ,
    "Missing Info."            ,
    "new_units"                ,
    "New Units"                ,
    "sale"                     ,
    "Sales"                    ,
    "new_units_cpi"            ,
    "New Units (CPI adjusted)" ,
    "sale_cpi"                 ,
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
    ~variable                   ,
    ~variable_label             ,
    "confidence"                ,
    "Confidence Index"          ,
    "activity"                  ,
    "Activity Index"            ,
    "interest"                  ,
    "Interest Rate"             ,
    "finance_condition"         ,
    "Financing Conditions"      ,
    "real_concession"           ,
    "Real Concessions"          ,
    "atractivity"               ,
    "Atractivity"               ,
    "employment"                ,
    "Jobs"                      ,
    "wage"                      ,
    "Wages"                     ,
    "real_estate_investing"     ,
    "Investment in Real Estate" ,
    "input_costs"               ,
    "Input Costs"               ,
    "new_units"                 ,
    "New Launches"              ,
    "real_estate_prices"        ,
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
    ~variable                                                   ,
    ~variable_label                                             ,
    "leading_index"                                             ,
    "Real Estate Leading Indicator (100 = dec/2000)"            ,
    "leading_index_12m"                                         ,
    "Real Estate Leading Indicator (% 12-month cumulative) (%)" ,
    "alvaras_total"                                             ,
    "Number of Building Permits (per month)"                    ,
    "alvaras_prop"                                              ,
    "Distribution of Building Permits in S\u00e3o Paulo (Total)"     ,
    "alvaras_total_12m"                                         ,
    "Building Permits (12-month cumulative)"                    ,
    "alvaras_prop_12m"                                          ,
    "Distribution of Building Permits in S\u00e3o Paulo (%)"
  )

  out <- list(
    indicator = list(names = ind_col_names, labels = ind_labels),
    radar = list(names = radar_col_names, labels = radar_labels),
    leading = list(names = lead_col_names, labels = lead_labels)
  )

  return(out)
}
