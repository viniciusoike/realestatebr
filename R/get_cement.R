# SNIC cement source readers ----

cement_states <- data.frame(
  name = c(
    "ROND\u00D4NIA",
    "ACRE",
    "AMAZONAS",
    "RORAIMA",
    "PAR\u00C1",
    "AMAP\u00C1",
    "TOCANTINS",
    "MARANH\u00C3O",
    "PIAU\u00CD",
    "CEAR\u00C1",
    "RIO GRANDE DO NORTE",
    "PARA\u00CDBA",
    "PERNAMBUCO",
    "ALAGOAS",
    "SERGIPE",
    "BAHIA",
    "MINAS GERAIS",
    "ESP\u00CDRITO SANTO",
    "RIO DE JANEIRO",
    "S\u00C3O PAULO",
    "PARAN\u00C1",
    "SANTA CATARINA",
    "RIO GRANDE DO SUL",
    "MATO GROSSO DO SUL",
    "MATO GROSSO",
    "GOI\u00C1S",
    "DISTRITO FEDERAL"
  ),
  abbrev = c(
    "RO",
    "AC",
    "AM",
    "RR",
    "PA",
    "AP",
    "TO",
    "MA",
    "PI",
    "CE",
    "RN",
    "PB",
    "PE",
    "AL",
    "SE",
    "BA",
    "MG",
    "ES",
    "RJ",
    "SP",
    "PR",
    "SC",
    "RS",
    "MS",
    "MT",
    "GO",
    "DF"
  ),
  code = c(
    11L,
    12L,
    13L,
    14L,
    15L,
    16L,
    17L,
    21L,
    22L,
    23L,
    24L,
    25L,
    26L,
    27L,
    28L,
    29L,
    31L,
    32L,
    33L,
    35L,
    41L,
    42L,
    43L,
    50L,
    51L,
    52L,
    53L
  ),
  region = c(rep(1L, 7), rep(2L, 9), rep(3L, 4), rep(4L, 3), rep(5L, 4))
)

cement_regions <- c(
  "NORTE" = 1L,
  "NORDESTE" = 2L,
  "SUDESTE" = 3L,
  "SUL" = 4L,
  "CENTRO-OESTE" = 5L
)

cement_months <- c(
  "JAN",
  "FEV",
  "MAR",
  "ABR",
  "MAI",
  "JUN",
  "JUL",
  "AGO",
  "SET",
  "OUT",
  "NOV",
  "DEZ"
)

cement_label <- function(value) {
  return(gsub("[[:space:]]+", " ", toupper(trimws(value))))
}

cement_number <- function(value, source) {
  value <- trimws(as.character(value))
  if (is.na(value) || value %in% c("", "-", "...", "....")) {
    return(NA_real_)
  }
  if (source == "pdf") {
    if (!grepl("^[0-9]{1,3}(\\.[0-9]{3})*$|^[0-9]+$", value)) {
      cli::cli_abort("Unexpected numeric token {.val {value}} in SNIC PDF.")
    }
    return(as.double(gsub(".", "", value, fixed = TRUE)))
  }
  if (!grepl("^[0-9]+(\\.[0-9]+)?$", value)) {
    cli::cli_abort("Unexpected numeric token {.val {value}} in cement archive.")
  }
  return(as.double(value))
}

cement_row <- function(
  year,
  label,
  values,
  source_kind,
  region_context = NA_integer_
) {
  label <- cement_label(label)
  if (label %in% cement_states$name) {
    state <- cement_states[match(label, cement_states$name), ]
    geography_type <- "state"
    code_region <- state$region
    abbrev_state <- state$abbrev
    code_state <- state$code
  } else if (label == "AJUSTES") {
    geography_type <- "adjustment"
    code_region <- region_context
    abbrev_state <- NA_character_
    code_state <- NA_integer_
  } else if (label == "BRASIL" || label == "TOTAL BRASIL") {
    geography_type <- "brazil"
    code_region <- NA_integer_
    abbrev_state <- NA_character_
    code_state <- NA_integer_
  } else {
    region_name <- sub("^REGI\u00C3O ", "", label)
    if (!region_name %in% names(cement_regions)) {
      cli::cli_abort(
        "Unexpected geography label {.val {label}} in cement source."
      )
    }
    geography_type <- "region"
    code_region <- unname(cement_regions[[region_name]])
    abbrev_state <- NA_character_
    code_state <- NA_integer_
  }
  if (geography_type == "adjustment" && is.na(code_region)) {
    cli::cli_abort("Ajustes row has no region context.")
  }
  tibble::tibble(
    date = as.Date(sprintf("%04d-%02d-01", year, seq_len(12))),
    geography_type = geography_type,
    code_region = as.integer(code_region),
    abbrev_state = abbrev_state,
    code_state = as.integer(code_state),
    value = as.double(values),
    unit = "tonnes",
    source_kind = source_kind
  )
}

resolve_snic_pdf_url <- function(index_html, label, index_url) {
  anchors <- rvest::html_elements(xml2::read_html(index_html), "a")
  labels <- trimws(rvest::html_text2(anchors))
  matches <- which(labels == label)
  if (length(matches) != 1L) {
    cli::cli_abort(
      "Expected one SNIC PDF link label {.val {label}}; found {length(matches)}."
    )
  }
  href <- rvest::html_attr(anchors[[matches]], "href")
  if (is.na(href) || !nzchar(href)) {
    cli::cli_abort("SNIC PDF link {.val {label}} has no URL.")
  }
  url <- xml2::url_absolute(href, index_url)
  if (
    !grepl("^https://snic\\.org\\.br/assets/pdf/numeros/[^/?#]+\\.pdf$", url)
  ) {
    cli::cli_abort("SNIC PDF URL has an unexpected host or path: {.url {url}}.")
  }
  return(url)
}

parse_cement_pdf <- function(text) {
  lines <- trimws(strsplit(gsub("\\f", "", text), "\\n")[[1]])
  title <- lines[grepl(
    "^CONSUMO APARENTE DE CIMENTO|^PRODU\u00C7\u00C3O NACIONAL DE CIMENTO",
    lines
  )]
  if (
    length(title) != 1L || !grepl(" POR REGI\u00D5ES E ESTADOS \\(t\\)$", title)
  ) {
    cli::cli_abort("Unexpected SNIC cement PDF title or layout.")
  }
  year_line <- lines[grepl("^20[0-9]{2}\\*$", lines)]
  if (length(year_line) != 1L) {
    cli::cli_abort("Unexpected SNIC PDF year title.")
  }
  year <- as.integer(sub("\\*$", "", year_line))
  header <- lines[grepl("^REGI\u00D5ES E ESTADOS", lines)]
  if (length(header) != 1L) {
    cli::cli_abort("Missing SNIC PDF month header.")
  }
  header_tokens <- strsplit(header, "[[:space:]]{2,}")[[1]]
  if (!identical(toupper(header_tokens[-1]), c(cement_months, "TOTAL"))) {
    cli::cli_abort("Unexpected SNIC PDF month header.")
  }
  start <- which(lines == header) + 1L
  rows <- lines[start:length(lines)]
  rows <- rows[nzchar(rows)]
  if (length(rows) != 37L) {
    if (sum(grepl("^Ajustes[[:space:]]", rows)) != 4L) {
      cli::cli_abort(
        "Unexpected duplicate or missing Ajustes adjustment row in SNIC PDF."
      )
    }
    cli::cli_abort("Expected 27 state rows and 10 other SNIC PDF rows.")
  }
  output <- vector("list", length(rows))
  region_context <- NA_integer_
  for (i in seq_along(rows)) {
    cells <- strsplit(rows[[i]], "[[:space:]]{2,}")[[1]]
    if (length(cells) != 14L) {
      cli::cli_abort("Unexpected SNIC PDF row layout or number of values.")
    }
    label <- cement_label(cells[[1]])
    if (grepl("^REGI\u00C3O ", label)) {
      region_name <- sub("^REGI\u00C3O ", "", label)
      if (!region_name %in% names(cement_regions)) {
        cli::cli_abort("Unknown SNIC region.")
      }
      region_context <- unname(cement_regions[[region_name]])
    }
    values <- vapply(cells[2:14], cement_number, numeric(1), source = "pdf")
    if (
      (!is.na(values[[13]]) &&
        abs(sum(values[1:12], na.rm = TRUE) - values[[13]]) > 0.001) ||
        (is.na(values[[13]]) && any(!is.na(values[1:12])))
    ) {
      cli::cli_abort(
        "SNIC PDF annual total does not reconcile for {.val {label}}."
      )
    }
    output[[i]] <- cement_row(
      year,
      label,
      values[1:12],
      "snic_pdf",
      region_context
    )
  }
  dat <- dplyr::bind_rows(output)
  counts <- table(factor(
    dat$geography_type[dat$date == as.Date(sprintf("%d-01-01", year))],
    levels = c("state", "adjustment", "region", "brazil")
  ))
  if (!identical(as.integer(counts), c(27L, 4L, 5L, 1L))) {
    cli::cli_abort(
      "SNIC PDF must have 27 states, four Ajustes, five regions, and Brazil."
    )
  }
  validate_cement_data(dat)
  return(dat)
}

read_cement_archive <- function(path, concept, years = NULL) {
  if (!concept %in% c("consumption", "production")) {
    cli::cli_abort("Unknown cement concept.")
  }
  sheets <- readxl::excel_sheets(path)
  if (is.null(years)) {
    years <- as.integer(sheets)
  }
  if (!all(as.character(years) %in% sheets)) {
    cli::cli_abort("Missing cement archive year sheet.")
  }
  output <- list()
  for (year in years) {
    sheet <- readxl::read_excel(
      path,
      sheet = as.character(year),
      col_names = FALSE,
      col_types = "text",
      .name_repair = "minimal"
    )
    raw <- as.matrix(sheet)
    expected_title <- if (concept == "consumption") {
      "CONSUMO MENSAL DE CIMENTO"
    } else {
      "PRODU\u00C7\u00C3O MENSAL DE CIMENTO"
    }
    if (
      !identical(unname(raw[1, 1]), expected_title) ||
        !grepl(paste0("^", year), raw[2, 1]) ||
        !unname(cement_label(raw[3, 14])) %in%
          c("EM TONELADAS", "(EM TONELADAS)") ||
        !identical(
          unname(cement_label(raw[5, 2:14])),
          c(cement_months, "TOTAL")
        )
    ) {
      cli::cli_abort(
        "Unexpected cement archive title, unit, or month header in {year}."
      )
    }
    end <- which(cement_label(raw[, 1]) == "TOTAL BRASIL")
    if (length(end) != 1L) {
      cli::cli_abort("Missing or duplicate Brazil total in archive {year}.")
    }
    brazil_months <- vapply(
      raw[end, 2:13],
      cement_number,
      numeric(1),
      source = "archive"
    )
    unpublished <- is.na(brazil_months) | brazil_months == 0
    if (any(diff(as.integer(unpublished)) < 0L)) {
      cli::cli_abort(
        "Cement archive {year} has a published month after an unpublished month."
      )
    }
    rows <- seq.int(6L, end)
    current_region <- NA_integer_
    for (i in rows) {
      label <- cement_label(raw[i, 1])
      if (label %in% cement_states$name) {
        current_region <- cement_states$region[match(label, cement_states$name)]
      }
      values <- vapply(
        raw[i, 2:13],
        cement_number,
        numeric(1),
        source = "archive"
      )
      annual <- cement_number(raw[i, 14], source = "archive")
      if (!is.na(annual) && abs(sum(values, na.rm = TRUE) - annual) > 0.01) {
        cli::cli_abort(
          "Cement archive {year} annual total does not reconcile for {.val {label}}."
        )
      }
      values[unpublished] <- NA_real_
      output[[length(output) + 1L]] <- cement_row(
        year,
        label,
        values,
        "archive",
        current_region
      )
    }
  }
  dat <- dplyr::bind_rows(output)
  validate_cement_data(dat)
  return(dat)
}

compare_cement_overlap <- function(archive, pdf) {
  keys <- c("date", "geography_type", "code_region", "code_state")
  joined <- dplyr::inner_join(
    dplyr::select(archive, dplyr::all_of(keys), archive_value = "value"),
    dplyr::select(pdf, dplyr::all_of(keys), pdf_value = "value"),
    by = keys
  )
  return(dplyr::filter(
    joined,
    !is.na(.data$archive_value),
    !is.na(.data$pdf_value),
    .data$archive_value != .data$pdf_value
  ))
}

splice_cement_sources <- function(archive, pdf) {
  dat <- dplyr::bind_rows(
    dplyr::filter(archive, .data$date < as.Date("2024-01-01")),
    dplyr::filter(pdf, .data$date >= as.Date("2024-01-01"))
  )
  validate_cement_data(dat)
  return(dat)
}

validate_cement_data <- function(data) {
  keys <- c("date", "geography_type", "code_region", "code_state")
  if (anyDuplicated(data[keys])) {
    cli::cli_abort("Cement data have a duplicate geography/date key.")
  }
  for (date in unique(data$date)) {
    month <- data[data$date == date, ]
    if (sum(month$geography_type == "state") != 27L) {
      cli::cli_abort("Cement data must include 27 state rows per month.")
    }
    for (region in 1:5) {
      states <- month$value[
        month$code_region == region & month$geography_type == "state"
      ]
      adjustments <- month$value[
        month$code_region == region & month$geography_type == "adjustment"
      ]
      total <- month$value[
        month$code_region == region & month$geography_type == "region"
      ]
      if (length(total) != 1L) {
        cli::cli_abort("Missing cement region total.")
      }
      if (
        !is.na(total) &&
          any(!is.na(states)) &&
          abs(sum(c(states, adjustments), na.rm = TRUE) - total) > 0.001
      ) {
        cli::cli_abort("Cement region totals do not reconcile on {date}.")
      }
    }
    regions <- month$value[month$geography_type == "region"]
    brazil <- month$value[month$geography_type == "brazil"]
    if (length(brazil) != 1L || length(regions) != 5L) {
      cli::cli_abort("Missing Brazil or region total.")
    }
    if (
      !is.na(brazil) &&
        (any(is.na(regions)) || abs(sum(regions) - brazil) > 0.001)
    ) {
      cli::cli_abort("Cement Brazil total does not reconcile on {date}.")
    }
  }
  return(invisible(data))
}

download_cement_pdf <- function(url, destfile, download = NULL) {
  if (
    !grepl("^https://snic\\.org\\.br/assets/pdf/numeros/[^/?#]+\\.pdf$", url)
  ) {
    cli::cli_abort("Invalid SNIC PDF URL.")
  }
  if (is.null(download)) {
    download <- function(url, destfile) {
      response <- httr::GET(url, httr::write_disk(destfile, overwrite = TRUE))
      httr::stop_for_status(response)
      return(destfile)
    }
  }
  result <- tryCatch(
    download_with_retry(
      function() download(url, destfile),
      max_retries = 2L,
      quiet = TRUE,
      desc = "SNIC PDF"
    ),
    error = function(cnd) {
      reason <- root_cause_message(cnd)
      if (
        grepl(
          "certificate.*expired|expired.*certificate",
          reason,
          ignore.case = TRUE
        )
      ) {
        cli::cli_abort(
          "SNIC TLS certificate has expired; PDF refresh is unavailable until SNIC renews it.",
          parent = cnd
        )
      }
      cli::cli_abort("SNIC PDF download failed: {reason}", parent = cnd)
    }
  )
  return(result)
}

#' @keywords internal
get_cement <- function(table = "consumption", quiet = FALSE) {
  cli::cli_abort(c(
    "Fresh cement data are unavailable from the installed package.",
    "i" = "The historical archive is not distributed; use the GitHub release snapshot when published."
  ))
}
