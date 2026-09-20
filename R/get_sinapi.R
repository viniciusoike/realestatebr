# SINAPI constants -----------------------------------------------------------

sinapi_tables <- c(
  with_payroll_relief = 2296L,
  without_payroll_relief = 6586L
)

sinapi_variable_names <- c(
  "48" = "cost",
  "2119" = "materials_cost",
  "2120" = "labor_cost",
  "49" = "cost_index",
  "1193" = "materials_index",
  "1232" = "labor_index",
  "1196" = "monthly_change",
  "1197" = "year_to_date_change",
  "1198" = "twelve_month_change",
  "9327" = "cost",
  "9328" = "materials_cost",
  "9329" = "labor_cost",
  "9330" = "cost_index",
  "9331" = "materials_index",
  "9332" = "labor_index",
  "9333" = "monthly_change",
  "9334" = "year_to_date_change",
  "9335" = "twelve_month_change"
)

sinapi_geography_names <- c(
  "N1" = "brazil",
  "N2" = "region",
  "N3" = "state"
)

# Get SINAPI data ------------------------------------------------------------

#' Get SINAPI Construction Costs and Indices
#'
#' Downloads monthly SINAPI costs, indices, and percentage changes from IBGE
#' for Brazil, the five geographic regions, and all states. The result includes
#' series both with and without payroll-tax relief.
#'
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return A tibble with monthly construction costs, indices, and percentage
#'   changes by geography and payroll-relief treatment.
#'
#' @source IBGE Sistema Nacional de Pesquisa de Custos e Índices da Construção
#'   Civil (SINAPI), SIDRA tables 2296 and 6586
#' @keywords internal
get_sinapi <- function(quiet = FALSE, max_retries = 3L) {
  if (!rlang::is_bool(quiet)) {
    cli::cli_abort("{.arg quiet} must be `TRUE` or `FALSE`.")
  }
  if (
    !is.numeric(max_retries) ||
      length(max_retries) != 1 ||
      is.na(max_retries) ||
      max_retries < 1
  ) {
    cli::cli_abort("{.arg max_retries} must be a positive integer.")
  }

  cli_user("Downloading SINAPI data from IBGE", quiet = quiet)

  with_relief <- download_ibge_aggregate(
    aggregate = sinapi_tables[["with_payroll_relief"]],
    localities = "N1[all]|N2[all]|N3[all]",
    quiet = quiet,
    max_retries = max_retries
  )
  without_relief <- download_ibge_aggregate(
    aggregate = sinapi_tables[["without_payroll_relief"]],
    localities = "N1[all]|N2[all]|N3[all]",
    quiet = quiet,
    max_retries = max_retries
  )

  data <- clean_sinapi(with_relief, without_relief)
  validate_sinapi(data)

  data <- attach_dataset_metadata(
    data,
    source = "web",
    extra_info = list(sidra_tables = unname(sinapi_tables))
  )

  cli_user("SINAPI data retrieved: {nrow(data)} records", quiet = quiet)

  return(data)
}

clean_sinapi <- function(with_relief, without_relief) {
  dat <- dplyr::bind_rows(
    with_relief = with_relief,
    without_relief = without_relief,
    .id = "payroll_relief"
  )
  dat$payroll_relief <- dat$payroll_relief == "with_relief"
  variable <- unname(sinapi_variable_names[dat$variable_id])
  geography_type <- unname(
    sinapi_geography_names[dat$geography_level]
  )

  if (anyNA(variable)) {
    unknown <- unique(dat$variable_id[is.na(variable)])
    cli::cli_abort("Unknown SINAPI variable ID: {.val {unknown}}.")
  }
  if (anyNA(geography_type)) {
    unknown <- unique(dat$geography_level[is.na(geography_type)])
    cli::cli_abort("Unknown SINAPI geography level: {.val {unknown}}.")
  }

  dat <- tibble::tibble(
    date = as.Date(paste0(dat$period, "01"), format = "%Y%m%d"),
    geography_type = geography_type,
    geography_code = dat$geography_code,
    geography_name = dat$geography_name,
    payroll_relief = dat$payroll_relief,
    variable = variable,
    variable_label = dat$variable_name,
    unit = dat$unit,
    value = dat$value
  ) |>
    dplyr::filter(!is.na(.data$value)) |>
    dplyr::arrange(
      .data$date,
      .data$geography_type,
      .data$geography_code,
      .data$payroll_relief,
      .data$variable
    )

  return(dat)
}

validate_sinapi <- function(dat) {
  validate_dataset(
    dat,
    dataset_name = "sinapi",
    required_cols = c(
      "date",
      "geography_type",
      "geography_code",
      "geography_name",
      "payroll_relief",
      "variable",
      "unit",
      "value"
    ),
    min_rows = 1000
  )

  keys <- c(
    "date",
    "geography_type",
    "geography_code",
    "payroll_relief",
    "variable"
  )
  if (any(duplicated(dat[keys]))) {
    cli::cli_abort("SINAPI data contains duplicate observation keys.")
  }
  if (!setequal(unique(dat$payroll_relief), c(TRUE, FALSE))) {
    cli::cli_abort("SINAPI data must contain both payroll-relief variants.")
  }

  return(invisible(TRUE))
}
