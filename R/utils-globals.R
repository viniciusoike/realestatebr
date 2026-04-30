#' Global Variables Declaration
#'
#' Declares global variables used in tidyverse pipelines to avoid R CMD check NOTEs.
#' These variables are column names that exist in the data frames being processed.
#'
#' @noRd
#' @keywords internal
utils::globalVariables(c(
  # RPPI-related variables
  "name_muni", "rent_price", "name_geo", "index", "chg", "acum12m",
  "market", "rooms", "variable", "rent_sale", "category", "value",
  "name_simplified", "abbrev_state", "code_muni", "dim_city", "fgv_data",
  "mes", "date", "info",

  # Common data variables
  "year",

  # BCB variables
  "Data", "Info", "Valor", "series_info", "bcb_metadata", "code_bcb",
  "category_label", "tab", "type", "id_cols", "names_from",

  # BIS variables
  "Period", "code", "unit", "is_nominal",

  # SBPE variables
  "sbpe_netflow_pct", "inflow", "stock", "sbpe_stock", "rural_stock",
  "sbpe_netflow", "rural_netflow",

  # Common tidyverse column specs
  "cols", "col_character", "col_number", "col_date",

  # Other data processing variables
  "city_name", "month", "month_label", "weighted_median_contract_rent_per_sqm",
  "var_percent_12_meses", "name", "zone", "label", "title",

  # tidyxl column names (R/utils.R)
  "address", "data_type",

  # FGV IBRE variables (R/get_fgv_ibre.R)
  "code_series", "name_series",

  # BIS RPPI variables (R/get_rppi_bis.R)
  "freq_name", "obs_value_observation_value",
  "time_period_time_period_or_range", "time", "unit_code", "unit_value_code",

  # Conditionally-called function (R/get-dataset.R)
  "translate_dataset"
))
