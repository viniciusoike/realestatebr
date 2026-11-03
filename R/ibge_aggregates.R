# IBGE SIDRA API -------------------------------------------------------------

ibge_sidra_base_url <- "https://apisidra.ibge.gov.br/values"

download_ibge_aggregate <- function(
  aggregate,
  variables = "all",
  periods = NULL,
  localities = "N1[all]",
  classifications = NULL,
  quiet = FALSE,
  max_retries = 3L,
  chunk_size = 120L
) {
  if (is.null(periods)) {
    periods <- download_ibge_periods(
      aggregate,
      quiet = quiet,
      max_retries = max_retries
    )
  }

  period_chunks <- split(
    as.character(periods),
    ceiling(seq_along(periods) / chunk_size)
  )

  chunks <- purrr::map(
    period_chunks,
    function(period_chunk) {
      url <- build_ibge_aggregate_url(
        aggregate = aggregate,
        variables = variables,
        periods = period_chunk,
        localities = localities,
        classifications = classifications
      )
      raw <- download_ibge_json(
        url,
        quiet = quiet,
        max_retries = max_retries,
        description = paste("IBGE aggregate", aggregate)
      )
      parse_sidra_response(raw, aggregate, classifications)
    }
  )

  return(fill_sidra_units(dplyr::bind_rows(chunks)))
}

# SIDRA leaves the unit empty on rows from before a variable starts, so those
# rows take the unit reported for the same variable elsewhere in the table.
fill_sidra_units <- function(dat) {
  if (nrow(dat) == 0) {
    return(dat)
  }

  reported <- dat[!is.na(dat$unit) & dat$unit != "", ]
  units <- reported$unit[match(dat$variable_id, reported$variable_id)]
  dat$unit <- dplyr::if_else(is.na(dat$unit) | dat$unit == "", units, dat$unit)

  return(dat)
}

download_ibge_periods <- function(aggregate, quiet, max_retries) {
  url <- paste0(
    ibge_sidra_base_url,
    "/t/",
    aggregate,
    "/n1/all/v/all/p/all/f/c/h/y"
  )
  raw <- download_ibge_json(
    url,
    quiet = quiet,
    max_retries = max_retries,
    description = paste("IBGE aggregate", aggregate, "period list")
  )

  return(sort(unique(raw$D3C[-1])))
}

# "N1[all]|N3[11,12]" becomes "n1/all/n3/11,12", and prefix "c" does the same
# for "24[103340]|76[2630]".
sidra_selection_path <- function(selection, prefix = "") {
  parts <- strsplit(selection, "|", fixed = TRUE)[[1]]
  path <- sub("^([^\\[]+)\\[(.*)\\]$", "\\1/\\2", parts)

  return(paste0(prefix, path, collapse = "/"))
}

build_ibge_aggregate_url <- function(
  aggregate,
  variables,
  periods,
  localities,
  classifications = NULL
) {
  segments <- c(
    paste0("t/", aggregate),
    tolower(sidra_selection_path(localities)),
    paste0("v/", paste(variables, collapse = ",")),
    paste0("p/", paste(periods, collapse = ",")),
    if (!is.null(classifications)) {
      sidra_selection_path(classifications, prefix = "c")
    },
    "f/a/h/y/d/m"
  )

  return(paste(c(ibge_sidra_base_url, segments), collapse = "/"))
}

download_ibge_json <- function(url, quiet, max_retries, description) {
  return(download_with_retry(
    fn = function() {
      response <- httr::GET(
        url,
        httr::user_agent(
          "realestatebr R package (https://github.com/viniciusoike/realestatebr)"
        ),
        httr::accept_json(),
        httr::timeout(60)
      )
      httr::stop_for_status(response)

      text <- httr::content(response, as = "text", encoding = "UTF-8")
      jsonlite::fromJSON(text)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = description
  ))
}

# SIDRA returns a header row, then D1 = geography, D2 = variable, D3 = period,
# and one more dimension per requested classification, in request order.
parse_sidra_response <- function(raw, aggregate, classifications) {
  if (nrow(raw) <= 1L) {
    return(tibble::tibble())
  }

  classification_ids <- character()
  if (!is.null(classifications)) {
    parts <- strsplit(classifications, "|", fixed = TRUE)[[1]]
    classification_ids <- sub("\\[.*$", "", parts)
  }

  dimension_count <- sum(grepl("^D[0-9]+C$", names(raw)))
  if (
    dimension_count != 3L + length(classification_ids) ||
      !identical(raw$D2N[[1]], "Vari\u00e1vel")
  ) {
    cli::cli_abort(
      "Unexpected SIDRA layout for table {.val {aggregate}}: \\
      {.val {unlist(raw[1, grepl('^D[0-9]+N$', names(raw))])}}."
    )
  }

  rows <- raw[-1, , drop = FALSE]
  dat <- tibble::tibble(
    aggregate_id = rep(as.character(aggregate), nrow(rows)),
    variable_id = rows$D2C,
    variable_name = rows$D2N,
    unit = rows$MN,
    period = rows$D3C,
    geography_level = paste0(rep("N", nrow(rows)), rows$NC),
    geography_level_name = rows$NN,
    geography_code = rows$D1C,
    geography_name = rows$D1N,
    value_raw = rows$V,
    value = parse_ibge_value(rows$V)
  )

  for (i in seq_along(classification_ids)) {
    prefix <- paste0("classification_", classification_ids[[i]])
    dat[[paste0(prefix, "_code")]] <- rows[[paste0("D", i + 3L, "C")]]
    dat[[paste0(prefix, "_name")]] <- rows[[paste0("D", i + 3L, "N")]]
  }

  return(dat)
}

parse_ibge_value <- function(x) {
  x <- as.character(x)
  x[x == "-"] <- "0"
  x[x %in% c("..", "...", "X", "X ")] <- NA_character_

  return(readr::parse_double(x, na = character()))
}
