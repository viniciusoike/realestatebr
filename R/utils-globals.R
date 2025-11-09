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

  # CBIC variables
  "link", "file_path", "year", "consumption", "growth_pct", "region",
  "Brasil", "state", "localidade", "code_state", "TOTAL", "name_state",
  "download_success", "month_num", "month_abb", "avg_price", "series_name",
  "product",

  # BCB variables
  "Data", "Info", "Valor", "series_info", "bcb_metadata", "code_bcb",
  "category_label", "tab", "type", "id_cols", "names_from",

  # BIS variables
  "Period", "code", "unit", "is_nominal",

  # SBPE variables
  "sbpe_netflow_pct", "inflow", "stock", "sbpe_stock", "rural_stock",
  "sbpe_netflow", "rural_netflow",

  # ITBI/Property records variables
  "df", "code_iptu_sql", "itbi_transaction_date", "yearmonth", "ts_date",
  "house_address", "ts_year", "address", "data_type",

  # Clean RI variables
  "name_sp_region", "sale_total", "name_sp_label", "record_total",
  "transfer_type", "code_region", "name_region",

  # Common tidyverse column specs
  "cols", "col_character", "col_number", "col_date",

  # Other data processing variables
  "city_name", "month", "month_label", "weighted_median_contract_rent_per_sqm",
  "var_percent_12_meses", "name", "zone", "label", "title"
))
