# PNAD Housing constants -----------------------------------------------------

pnad_housing_tables <- c(
  tenure = 6821L,
  dwelling_type = 6820L,
  household_size = 6678L,
  mean_household_size = 6578L,
  household_composition = 6788L
)

pnad_housing_table_variables <- list(
  tenure = c("162", "5123", "9784", "9785"),
  dwelling_type = c("162", "5123", "9784", "9785"),
  household_size = c("162", "5123", "9784", "9785"),
  mean_household_size = c("10163", "10164"),
  household_composition = c("162", "5123")
)

pnad_housing_variables <- tibble::tribble(
  ~variable_id , ~variable            , ~unit          ,
  "162"        , "households"         , "Mil unidades" ,
  "5123"       , "households_cv"      , "%"            ,
  "9784"       , "household_share"    , "%"            ,
  "9785"       , "household_share_cv" , "%"            ,
  "10163"      , "mean_residents"     , "Pessoas"      ,
  "10164"      , "mean_residents_cv"  , "%"
)

pnad_housing_geography_names <- c(
  N1 = "brazil",
  N2 = "region",
  N3 = "state",
  N6 = "capital",
  N7 = "metropolitan_region",
  N14 = "integrated_development_region"
)

pnad_housing_expected_geography_codes <- list(
  N1 = "1",
  N2 = as.character(1:5),
  N3 = c(
    "11",
    "12",
    "13",
    "14",
    "15",
    "16",
    "17",
    "21",
    "22",
    "23",
    "24",
    "25",
    "26",
    "27",
    "28",
    "29",
    "31",
    "32",
    "33",
    "35",
    "41",
    "42",
    "43",
    "50",
    "51",
    "52",
    "53"
  ),
  N6 = c(
    "1100205",
    "1200401",
    "1302603",
    "1400100",
    "1501402",
    "1600303",
    "1721000",
    "2111300",
    "2211001",
    "2304400",
    "2408102",
    "2507507",
    "2611606",
    "2704302",
    "2800308",
    "2927408",
    "3106200",
    "3205309",
    "3304557",
    "3550308",
    "4106902",
    "4205407",
    "4314902",
    "5002704",
    "5103403",
    "5208707",
    "5300108"
  ),
  N7 = c(
    "1301",
    "1501",
    "1601",
    "2101",
    "2301",
    "2401",
    "2501",
    "2601",
    "2701",
    "2801",
    "2901",
    "3101",
    "3201",
    "3301",
    "3501",
    "4101",
    "4201",
    "4301",
    "5101",
    "5201"
  ),
  N14 = "510"
)

pnad_housing_classifications <- c(
  tenure = "63",
  dwelling_type = "125",
  household_size = "68",
  mean_household_size = NA_character_,
  household_composition = "460"
)

pnad_housing_categories <- list(
  tenure = c(
    "95826" = "total",
    "4342" = "owned_paid",
    "4343" = "owned_paying",
    "1055" = "rented",
    "2519" = "ceded",
    "1058" = "other"
  ),
  dwelling_type = c(
    "2932" = "total",
    "6815" = "house",
    "3247" = "apartment",
    "121265" = "rooming_house"
  ),
  household_size = c(
    "9902" = "total",
    "1092" = "one_resident",
    "1093" = "two_residents",
    "1094" = "three_residents",
    "1095" = "four_residents",
    "1096" = "five_residents",
    "47267" = "six_plus_residents"
  ),
  mean_household_size = NULL,
  household_composition = c(
    "45902" = "total",
    "12076" = "one_person",
    "12077" = "nuclear",
    "12078" = "extended",
    "12079" = "composite"
  )
)

pnad_housing_localities <- paste(
  "N1[all]",
  "N2[all]",
  "N3[all]",
  "N6[all]",
  "N7[all]",
  "N14[all]",
  sep = "|"
)

# Import --------------------------------------------------------------------

get_pnad_housing <- function(
  table = "tenure",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- names(pnad_housing_tables)
  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  cli_user("Downloading PNAD Housing data from IBGE", quiet = quiet)

  tables <- if (table == "all") valid_tables else table
  out <- list()
  for (tbl in tables) {
    raw <- download_pnad_housing_table(
      tbl,
      quiet = quiet,
      max_retries = max_retries
    )
    cleaned <- clean_pnad_housing(raw, tbl)
    validate_pnad_housing(cleaned, tbl)
    out[[tbl]] <- attach_dataset_metadata(
      cleaned,
      source = "web",
      category = tbl,
      extra_info = list(sidra_table = unname(pnad_housing_tables[[tbl]]))
    )
  }

  if (table == "all") {
    cli_user("PNAD Housing data retrieved: {length(out)} tables", quiet = quiet)
    return(out)
  }

  dat <- out[[table]]
  cli_user("PNAD Housing data retrieved: {nrow(dat)} records", quiet = quiet)

  return(dat)
}

download_pnad_housing_table <- function(table, quiet, max_retries) {
  aggregate <- unname(pnad_housing_tables[[table]])
  periods <- download_ibge_periods(
    aggregate,
    quiet = quiet,
    max_retries = max_retries
  )
  classification <- pnad_housing_classifications[[table]]
  classifications <- if (is.na(classification)) {
    NULL
  } else if (table == "household_composition") {
    "293[100311]|460[all]"
  } else {
    paste0(classification, "[all]")
  }

  dat <- download_ibge_aggregate(
    aggregate = aggregate,
    variables = pnad_housing_table_variables[[table]],
    periods = periods,
    localities = pnad_housing_localities,
    classifications = classifications,
    quiet = quiet,
    max_retries = max_retries
  )
  attr(dat, "published_periods") <- periods

  return(dat)
}

# Cleaning ------------------------------------------------------------------

clean_pnad_housing <- function(raw, table) {
  expected_table <- unname(pnad_housing_tables[[table]])
  if (nrow(raw) == 0) {
    cli::cli_abort(
      "PNAD Housing response for SIDRA table {.val {expected_table}} is empty."
    )
  }
  if (!identical(unique(raw$aggregate_id), as.character(expected_table))) {
    cli::cli_abort(
      "PNAD Housing response is not from SIDRA table {.val {expected_table}}."
    )
  }

  allowed_variables <- pnad_housing_table_variables[[table]]
  unexpected_variables <- setdiff(unique(raw$variable_id), allowed_variables)
  if (length(unexpected_variables) > 0) {
    cli::cli_abort(
      "Unknown PNAD Housing variable ID: {.val {unexpected_variables}}."
    )
  }

  variable_row <- match(raw$variable_id, pnad_housing_variables$variable_id)
  variable_info <- pnad_housing_variables[variable_row, ]
  bad_unit <- is.na(raw$unit) |
    raw$unit == "" |
    raw$unit != variable_info$unit
  if (any(bad_unit)) {
    bad_variables <- unique(raw$variable_id[bad_unit])
    cli::cli_abort(
      "Unexpected unit for PNAD Housing variable ID: {.val {bad_variables}}."
    )
  }

  geography_type <- unname(
    pnad_housing_geography_names[raw$geography_level]
  )
  if (anyNA(geography_type)) {
    unknown <- unique(raw$geography_level[is.na(geography_type)])
    cli::cli_abort("Unknown PNAD Housing geography level: {.val {unknown}}.")
  }
  if (anyNA(raw$geography_code) || any(raw$geography_code == "")) {
    cli::cli_abort(
      "PNAD Housing data contains observations without a geography code."
    )
  }

  year <- suppressWarnings(as.integer(raw$period))
  if (anyNA(year)) {
    cli::cli_abort(
      "PNAD Housing data contains observations without a reference year."
    )
  }

  classification_id <- pnad_housing_classifications[[table]]
  if (is.na(classification_id)) {
    category_id <- rep(NA_character_, nrow(raw))
    category <- rep(NA_character_, nrow(raw))
    category_name_pt <- rep(NA_character_, nrow(raw))
  } else {
    category_id <- pnad_housing_classification(raw, classification_id)
    category_name_pt <- pnad_housing_classification(
      raw,
      classification_id,
      suffix = "name"
    )
    category <- unname(pnad_housing_categories[[table]][category_id])
    if (anyNA(category)) {
      unknown <- unique(category_id[is.na(category)])
      cli::cli_abort("Unknown PNAD Housing category ID: {.val {unknown}}.")
    }
  }

  if (table == "household_composition") {
    reference_sex <- pnad_housing_classification(raw, "293")
    if (!all(reference_sex == "100311")) {
      cli::cli_abort(
        "PNAD Housing composition must use total reference-person sex."
      )
    }
  }

  value_status <- pnad_housing_value_status(raw$value_raw)
  dat <- tibble::tibble(
    year = year,
    source_table = rep(as.integer(expected_table), nrow(raw)),
    geography_type = geography_type,
    geography_code = as.character(raw$geography_code),
    geography_name = raw$geography_name,
    geography_level_name = raw$geography_level_name,
    classification_id = rep(classification_id, nrow(raw)),
    category_id = category_id,
    category = category,
    category_name_pt = category_name_pt,
    variable_id = raw$variable_id,
    variable = variable_info$variable,
    variable_name_pt = raw$variable_name,
    unit = raw$unit,
    value = raw$value,
    value_raw = raw$value_raw,
    value_status = value_status
  )

  dat <- dplyr::arrange(
    dat,
    .data$year,
    .data$geography_type,
    .data$geography_code,
    .data$variable_id,
    .data$category_id
  )
  attr(dat, "published_periods") <- attr(raw, "published_periods")

  return(dat)
}

pnad_housing_classification <- function(
  raw,
  classification_id,
  suffix = "code"
) {
  column <- paste0("classification_", classification_id, "_", suffix)
  if (!column %in% names(raw)) {
    cli::cli_abort(
      "PNAD Housing response lacks classification {.val {classification_id}}."
    )
  }

  return(raw[[column]])
}

pnad_housing_value_status <- function(value_raw) {
  value_raw <- trimws(value_raw)
  status <- rep(NA_character_, length(value_raw))
  status[is.na(value_raw) | value_raw == ""] <- "missing"
  status[!is.na(value_raw) & value_raw == "-"] <- "zero"
  status[!is.na(value_raw) & value_raw == ".."] <- "not_applicable"
  status[!is.na(value_raw) & value_raw == "..."] <- "not_available"
  status[!is.na(value_raw) & value_raw == "X"] <- "suppressed"
  numeric_value <- !is.na(value_raw) &
    grepl(
      "^-?[0-9]+([.,][0-9]+)?$",
      value_raw
    )
  status[numeric_value] <- "observed"

  if (anyNA(status)) {
    unknown <- unique(value_raw[is.na(status)])
    cli::cli_abort("Unknown PNAD Housing value symbol: {.val {unknown}}.")
  }

  return(status)
}

# Validation ----------------------------------------------------------------

validate_pnad_housing <- function(dat, table, call = rlang::caller_env()) {
  keys <- c(
    "year",
    "source_table",
    "geography_type",
    "geography_code",
    "variable_id",
    "category_id"
  )
  check <- dplyr::summarise(
    dat,
    n = dplyr::n(),
    .by = dplyr::all_of(keys)
  )
  if (any(check$n > 1)) {
    cli::cli_abort(
      "PNAD Housing {table} data contains duplicate observation keys.",
      call = call
    )
  }

  published_periods <- suppressWarnings(
    as.integer(attr(dat, "published_periods"))
  )
  if (length(published_periods) == 0 || anyNA(published_periods)) {
    cli::cli_abort(
      "PNAD Housing {table} data lacks its published-period contract.",
      call = call
    )
  }
  if (!setequal(dat$year, published_periods)) {
    cli::cli_abort(
      "PNAD Housing {table} data does not contain every published period.",
      call = call
    )
  }

  expected_variables <- pnad_housing_table_variables[[table]]
  missing_variables <- setdiff(expected_variables, unique(dat$variable_id))
  unexpected_variables <- setdiff(unique(dat$variable_id), expected_variables)
  if (length(missing_variables) > 0 || length(unexpected_variables) > 0) {
    cli::cli_abort(
      "PNAD Housing {table} data does not match the variable contract.",
      call = call
    )
  }

  if (table != "mean_household_size") {
    expected_categories <- names(pnad_housing_categories[[table]])
    missing_categories <- setdiff(expected_categories, unique(dat$category_id))
    unexpected_categories <- setdiff(
      unique(dat$category_id),
      expected_categories
    )
    if (length(missing_categories) > 0 || length(unexpected_categories) > 0) {
      cli::cli_abort(
        "PNAD Housing {table} data does not match the category contract.",
        call = call
      )
    }
  }

  groups <- dplyr::distinct(
    dat,
    .data$year,
    .data$source_table,
    .data$geography_type,
    .data$geography_code
  )
  categories <- if (table == "mean_household_size") {
    NA_character_
  } else {
    names(pnad_housing_categories[[table]])
  }
  expected <- tidyr::expand_grid(
    groups,
    variable_id = expected_variables,
    category_id = categories
  )
  missing <- dplyr::anti_join(expected, dat, by = keys)
  unexpected <- dplyr::anti_join(dat[keys], expected, by = keys)
  if (nrow(missing) > 0 || nrow(unexpected) > 0) {
    cli::cli_abort(
      "PNAD Housing {table} data does not match its published observation grid.",
      call = call
    )
  }

  if (table != "household_composition" && any(dat$year %in% c(2020L, 2021L))) {
    cli::cli_abort(
      "PNAD Housing {table} contains unpublished 2020 or 2021 rows.",
      call = call
    )
  }

  validate_pnad_housing_geographies(dat, table, call = call)
  validate_pnad_housing_reconciliation(dat, table, call = call)

  return(invisible(TRUE))
}

validate_pnad_housing_geographies <- function(
  dat,
  table,
  call = rlang::caller_env()
) {
  expected_codes <- lapply(
    names(pnad_housing_expected_geography_codes),
    function(level) {
      tibble::tibble(
        geography_level = level,
        geography_code = pnad_housing_expected_geography_codes[[level]]
      )
    }
  )
  expected_codes <- dplyr::bind_rows(expected_codes)
  expected <- tidyr::expand_grid(
    year = unique(dat$year),
    expected_codes
  )
  expected$geography_type <- unname(
    pnad_housing_geography_names[expected$geography_level]
  )
  actual <- dplyr::distinct(
    dat,
    .data$year,
    .data$geography_type,
    .data$geography_code
  )
  keys <- c("year", "geography_type", "geography_code")
  missing <- dplyr::anti_join(expected, actual, by = keys)
  unexpected <- dplyr::anti_join(actual, expected, by = keys)
  if (nrow(missing) > 0 || nrow(unexpected) > 0) {
    cli::cli_abort(
      "PNAD Housing {table} data does not contain every published geographic domain.",
      call = call
    )
  }

  return(invisible(TRUE))
}

validate_pnad_housing_reconciliation <- function(
  dat,
  table,
  call = rlang::caller_env()
) {
  if (table == "mean_household_size") {
    return(invisible(TRUE))
  }

  counts <- dat[dat$variable == "households", ]
  count_check <- dplyr::summarise(
    counts,
    total = sum(.data$value[.data$category == "total"]),
    components = sum(.data$value[.data$category != "total"]),
    component_count = sum(.data$category != "total"),
    .by = c("year", "geography_type", "geography_code")
  )
  count_tolerance <- (count_check$component_count + 1) / 2
  bad_counts <- !is.na(count_check$total) &
    !is.na(count_check$components) &
    abs(count_check$total - count_check$components) > count_tolerance
  if (any(bad_counts)) {
    cli::cli_abort(
      "PNAD Housing {table} category counts do not reconcile with totals.",
      call = call
    )
  }

  if (!"household_share" %in% dat$variable) {
    return(invisible(TRUE))
  }

  shares <- dat[dat$variable == "household_share", ]
  share_check <- dplyr::summarise(
    shares,
    components = sum(.data$value[.data$category != "total"]),
    component_count = sum(.data$category != "total"),
    .by = c("year", "geography_type", "geography_code")
  )
  share_tolerance <- share_check$component_count * 0.05 + 1e-8
  bad_shares <- !is.na(share_check$components) &
    abs(share_check$components - 100) > share_tolerance
  if (any(bad_shares)) {
    cli::cli_abort(
      "PNAD Housing {table} category shares do not sum to 100 within rounding tolerance.",
      call = call
    )
  }

  count_values <- counts[c(
    "year",
    "geography_type",
    "geography_code",
    "category",
    "value"
  )]
  names(count_values)[[5]] <- "count"
  share_values <- shares[c(
    "year",
    "geography_type",
    "geography_code",
    "category",
    "value"
  )]
  names(share_values)[[5]] <- "share"
  totals <- count_values[count_values$category == "total", ]
  totals$category <- NULL
  names(totals)[[4]] <- "total"
  comparison_keys <- c("year", "geography_type", "geography_code", "category")
  comparison <- dplyr::inner_join(
    count_values[count_values$category != "total", ],
    share_values[share_values$category != "total", ],
    by = comparison_keys
  )
  comparison <- dplyr::left_join(
    comparison,
    totals,
    by = c("year", "geography_type", "geography_code")
  )
  derived_share <- comparison$count / comparison$total * 100
  bad_comparison <- !is.na(comparison$share) &
    !is.na(derived_share) &
    abs(comparison$share - derived_share) > 0.7
  if (any(bad_comparison)) {
    cli::cli_abort(
      "PNAD Housing {table} published shares do not reconcile with category counts.",
      call = call
    )
  }

  return(invisible(TRUE))
}
