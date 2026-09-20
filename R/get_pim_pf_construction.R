# PIM-PF construction-input constants ---------------------------------------

pim_pf_old_table <- 2294L
pim_pf_current_table <- 8886L
pim_pf_old_variable <- 28L
pim_pf_current_variable <- 12606L
pim_pf_link_year <- 2012L

# Get PIM-PF construction-input data ----------------------------------------

#' Get PIM-PF Construction-input Production Index
#'
#' Downloads and links the monthly IBGE physical-production index for inputs
#' typically used in construction. The historical series from SIDRA table 2294
#' is rescaled to the 2022-reference series in table 8886 using the ratio of
#' their 2012 annual means.
#'
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return A tibble containing one linked monthly index from January 1991.
#'
#' @source IBGE Pesquisa Industrial Mensal - Produção Física (PIM-PF), SIDRA
#'   tables 2294 and 8886
#' @keywords internal
get_pim_pf_construction <- function(quiet = FALSE, max_retries = 3L) {
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

  cli_user(
    "Downloading PIM-PF construction-input data from IBGE",
    quiet = quiet
  )

  old <- download_ibge_aggregate(
    aggregate = pim_pf_old_table,
    variables = pim_pf_old_variable,
    localities = "N1[all]",
    classifications = "24[103340]|76[2630]",
    quiet = quiet,
    max_retries = max_retries
  )
  current <- download_ibge_aggregate(
    aggregate = pim_pf_current_table,
    variables = pim_pf_current_variable,
    localities = "N1[all]",
    quiet = quiet,
    max_retries = max_retries
  )

  data <- link_pim_pf_construction(old, current)
  validate_pim_pf_construction(data)

  link_factor <- attr(data, "link_factor")
  data <- attach_dataset_metadata(
    data,
    source = "web",
    extra_info = list(
      sidra_tables = c(pim_pf_old_table, pim_pf_current_table),
      link_year = pim_pf_link_year,
      link_factor = link_factor
    )
  )

  cli_user(
    "PIM-PF construction-input data retrieved: {nrow(data)} records",
    quiet = quiet
  )

  return(data)
}

link_pim_pf_construction <- function(old, current) {
  old <- prepare_pim_pf_series(old, pim_pf_old_table)
  current <- prepare_pim_pf_series(current, pim_pf_current_table)

  link_start <- as.Date(paste0(pim_pf_link_year, "-01-01"))
  link_end <- as.Date(paste0(pim_pf_link_year, "-12-01"))
  old_overlap <- dplyr::filter(
    old,
    .data$date >= link_start,
    .data$date <= link_end
  )
  current_overlap <- dplyr::filter(
    current,
    .data$date >= link_start,
    .data$date <= link_end
  )

  if (nrow(old_overlap) != 12L || nrow(current_overlap) != 12L) {
    cli::cli_abort(
      "PIM-PF source tables do not contain a complete 2012 linking window."
    )
  }

  link_factor <- mean(current_overlap$value) / mean(old_overlap$value)
  historical <- old |>
    dplyr::filter(.data$date < link_start) |>
    dplyr::mutate(value = .data$value * link_factor)
  current <- current |>
    dplyr::filter(.data$date >= link_start)

  dat <- dplyr::bind_rows(
    `2294` = historical,
    `8886` = current,
    .id = "source_table"
  ) |>
    dplyr::mutate(
      variable = "construction_inputs_production_index",
      reference_period = "2022 average = 100",
      source_table = as.integer(.data$source_table)
    ) |>
    dplyr::select(dplyr::all_of(c(
      "date",
      "variable",
      "reference_period",
      "source_table",
      "value"
    ))) |>
    dplyr::arrange(.data$date)

  attr(dat, "link_factor") <- link_factor
  return(dat)
}

prepare_pim_pf_series <- function(dat, expected_table) {
  dat <- dplyr::filter(
    dat,
    .data$aggregate_id == as.character(expected_table),
    !is.na(.data$value)
  )

  return(tibble::tibble(
    date = as.Date(paste0(dat$period, "01"), format = "%Y%m%d"),
    value = dat$value
  ))
}

validate_pim_pf_construction <- function(dat) {
  validate_dataset(
    dat,
    dataset_name = "pim_pf_construction",
    required_cols = c(
      "date",
      "variable",
      "reference_period",
      "source_table",
      "value"
    ),
    min_rows = 400
  )

  if (anyDuplicated(dat$date) > 0) {
    cli::cli_abort("PIM-PF construction data contains duplicate months.")
  }
  expected_dates <- seq(min(dat$date), max(dat$date), by = "month")
  if (!identical(dat$date, expected_dates)) {
    cli::cli_abort("PIM-PF construction data contains missing months.")
  }
  if (any(dat$value <= 0)) {
    cli::cli_abort("PIM-PF construction index must contain positive values.")
  }

  return(invisible(TRUE))
}
