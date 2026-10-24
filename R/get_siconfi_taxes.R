# Internal machinery for the `siconfi_taxes` dataset: FINBRA bulk-file
# parsing, SICONFI DCA API parsing and fetching, and the long-to-wide
# builder/validator. The cache-only `get_dataset()` path is wired through
# the registry (no fresh download); rebuilds live in
# data-raw/siconfi/build_snapshot.R.
#
# See data-raw/siconfi/dataset-plan.md for the source design and the
# verified regression anchors.

# Vintages --------------------------------------------------------------------

# Tax account identifiers follow SICONFI account vintages: the same
# municipality tax appears under different PCASP codes in each period
# (verified against the FINBRA bulk files; see the plan). `ignore_re`
# lists the non-tax codes observed inside the vintage's tax family
# subtree, so a layout change fails loudly instead of silently dropping
# rows.
.siconfi_vintages <- list(
  list(
    start = 2013L,
    end = 2017L,
    family = "RO1.1.1.2.",
    iptu = "RO1.1.1.2.02.00.00",
    itbi = "RO1.1.1.2.08.00.00",
    ignore_re = "^RO1\\.1\\.1\\.2\\.[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}$"
  ),
  list(
    start = 2018L,
    end = 2021L,
    family = "RO1.1.1.8.",
    iptu = "RO1.1.1.8.01.1.0",
    itbi = "RO1.1.1.8.01.4.0",
    ignore_re = "^RO1\\.1\\.1\\.8\\.[0-9]{2}\\.[0-9]\\.[0-9]$"
  ),
  list(
    # 2022-onward vintage; the end is bumped ahead so new exercises keep
    # building until Tesouro recodes the accounts again.
    # shortcut: must be raised (or a new vintage added) once Tesouro
    # announces the next PCASP recode.
    start = 2022L,
    end = 2035L,
    family = "RO1.1.1.2.",
    iptu = "RO1.1.1.2.50.0.0",
    itbi = "RO1.1.1.2.53.0.0",
    ignore_re = "^RO1\\.1\\.1\\.2\\.[0-9]{2}\\.[0-9]\\.[0-9]$"
  )
)

# Column-label -> value-kind map. The 2013 bulk files use
# `Receitas Realizadas` / `Deduções da Receita` and 2014+ files use
# `Receitas Brutas Realizadas` / `Outras Deduções da Receita`; the API
# uses the 2014+ vocabulary for every year. FUNDEB and
# constitutional-transfer deduction columns never feed the published tax
# deductions (verified per the plan), so they become `excluded_deduction`.
.siconfi_label_kinds <- c(
  "Receitas Realizadas" = "gross",
  "Receitas Brutas Realizadas" = "gross",
  "Dedu\u00e7\u00f5es da Receita" = "deduction",
  "Outras Dedu\u00e7\u00f5es da Receita" = "deduction",
  "Dedu\u00e7\u00f5es - FUNDEB" = "excluded_deduction",
  "Dedu\u00e7\u00f5es - Transfer\u00eancias Constitucionais" = "excluded_deduction"
)

#' Find the SICONFI account vintage covering a year
#'
#' @noRd
siconfi_vintage_for_year <- function(year, call = caller_env()) {
  for (vintage in .siconfi_vintages) {
    if (year >= vintage$start && year <= vintage$end) {
      return(vintage)
    }
  }
  starts <- vapply(.siconfi_vintages, function(v) v$start, integer(1L))
  ends <- vapply(.siconfi_vintages, function(v) v$end, integer(1L))
  cli::cli_abort(
    c(
      "SICONFI exercise year {year} is not supported.",
      "i" = "Known account vintages cover {min(starts)} to {max(ends)}.",
      "i" = "Extend the vintage table in R/get_siconfi_taxes.R when \\
             Tesouro publishes new account codes."
    ),
    call = call
  )
}

#' Classify one SICONFI account identifier
#'
#' Returns `"iptu"`, `"itbi"`, or `NA` when the identifier belongs to a
#' non-tax row. Aborts on a tax code of another vintage and on an unknown
#' code inside the vintage's tax-family subtree: any layout change must
#' fail loudly, never silently drop rows.
#'
#' @param code Account identifier with the `siconfi-cor_` prefix removed.
#' @noRd
siconfi_classify_code <- function(code, year, call = caller_env()) {
  vintage <- siconfi_vintage_for_year(year, call = call)

  if (identical(code, vintage$iptu)) {
    return("iptu")
  }
  if (identical(code, vintage$itbi)) {
    return("itbi")
  }

  foreign_codes <- unlist(
    lapply(
      .siconfi_vintages,
      function(v) setdiff(c(v$iptu, v$itbi), c(vintage$iptu, vintage$itbi))
    )
  )
  if (code %in% foreign_codes) {
    cli::cli_abort(
      "Tax account {.val {code}} does not belong to the {year} vintage; \\
       the {year} codes are {vintage$iptu} and {vintage$itbi}.",
      call = call
    )
  }

  if (startsWith(code, vintage$family)) {
    if (grepl(vintage$ignore_re, code)) {
      return(NA_character_)
    }
    cli::cli_abort(
      "Unknown account in the {year} tax family: {.val {code}}.",
      call = call
    )
  }

  return(NA_character_)
}

# Shared helpers --------------------------------------------------------------

#' Parse a Brazilian decimal number strictly
#'
#' Decimal comma, no thousands separator. Any other shape aborts so the
#' parsers never guess a value.
#' @noRd
siconfi_parse_number <- function(x, call = caller_env()) {
  if (is.numeric(x)) {
    value <- as.double(x)[[1L]]
    if (is.na(value)) {
      cli::cli_abort("Missing numeric value in the SICONFI data.", call = call)
    }
    return(value)
  }
  raw_text <- gsub('"', "", as.character(x)[[1L]], fixed = TRUE)
  if (!grepl("^-?[0-9]+(,[0-9]+)?$", raw_text)) {
    cli::cli_abort(
      "Malformed numeric value {.val {raw_text}} in the SICONFI data.",
      call = call
    )
  }
  return(as.numeric(sub(",", ".", raw_text, fixed = TRUE)))
}

#' Strip quotes and the siconfi-cor_ prefix from an account identifier
#' @noRd
siconfi_clean_code <- function(identifier) {
  unquoted <- gsub('"', "", identifier, fixed = TRUE)
  trimws(sub("^siconfi-cor_", "", trimws(unquoted), fixed = FALSE))
}

#' Map a column label to a value kind or abort on an unknown label
#'
#' Only tax rows reach this helper, so an unknown label aborts with the
#' offending label in the message.
#' @noRd
siconfi_value_kind <- function(label, call = caller_env()) {
  kind_index <- match(label, names(.siconfi_label_kinds))
  if (is.na(kind_index)) {
    cli::cli_abort(
      "Unknown column label {.val {label}} on a tax row.",
      call = call
    )
  }
  return(unname(.siconfi_label_kinds[[kind_index]]))
}

#' Long-form tibble columns shared by the FINBRA and API parsers
#' @noRd
siconfi_long_columns <- function() {
  tibble::tibble(
    year = integer(),
    code_muni = character(),
    abbrev_state = character(),
    institution = character(),
    tax = character(),
    value_kind = character(),
    value = double()
  )
}

# FINBRA bulk files -----------------------------------------------------------

#' Read one FINBRA "Receitas Orçamentárias (Anexo I-C)" bulk file
#'
#' `path` may be a `.csv` or a `.zip` whose single CSV entry is read; the
#' exercise year comes from the `Exercício:` metadata line, never from
#' file names. The files are Windows-1252 (latin1) `;`-separated text
#' whose quoted account names may contain unescaped `"` and even `;`, so
#' no standard CSV reader is used: rows are identified by the fields read
#' from the end of the line (`Valor`, then `Identificador da Conta`), and
#' tax rows must keep exactly 8 fields.
#'
#' @return A tibble of tax rows in the long form (columns `year`,
#'   `code_muni` (character, 7 digits), `abbrev_state`, `institution`,
#'   `tax`, `value_kind`, `value`).
#' @keywords internal
read_finbra_file <- function(path, call = caller_env()) {
  lines <- finbra_read_lines(path, call = call)
  year <- finbra_year(lines, call = call)
  data_lines <- finbra_data_lines(lines)

  if (length(data_lines) == 0L) {
    cli::cli_abort(
      "FINBRA file {.path {path}} has no data rows.",
      call = call
    )
  }

  parsed <- lapply(data_lines, finbra_parse_line, year = year, call = call)
  tax_rows <- parsed[!vapply(parsed, is.null, logical(1L))]

  if (length(tax_rows) == 0L) {
    cli::cli_abort(
      "No IPTU or ITBI rows found in FINBRA file {.path {path}}.",
      call = call
    )
  }

  return(dplyr::bind_rows(tax_rows))
}

#' Read the FINBRA file lines, decoding latin1
#' @noRd
finbra_read_lines <- function(path, call = caller_env()) {
  if (!file.exists(path)) {
    cli::cli_abort("FINBRA file {.path {path}} not found.", call = call)
  }

  if (grepl("\\.zip$", path, ignore.case = TRUE)) {
    entries <- utils::unzip(path, list = TRUE)
    names <- entries$Name
    candidate <- names[grepl("\\.csv$", names, ignore.case = TRUE)][1L]
    if (is.na(candidate)) {
      candidate <- names[1L]
    }
    con <- unz(path, candidate)
    lines <- readLines(con, warn = FALSE)
    close(con)
  } else {
    lines <- readLines(path, warn = FALSE)
  }

  text <- iconv(lines, from = "latin1", to = "UTF-8")
  return(text)
}

#' Data lines of a FINBRA file
#'
#' Drops the three metadata lines (`Exercício:`, `Escopo:`, `Tabela:`) and
#' the header line by pattern, never by position.
#' @noRd
finbra_data_lines <- function(lines) {
  trimmed <- trimws(lines)
  keep <- !grepl("^Exerc", trimmed) &
    !grepl("^Escopo:", trimmed) &
    !grepl("^Tabela:", trimmed) &
    !grepl("^Institui\u00e7\u00e3o;", trimmed)
  return(lines[keep])
}

#' Extract the exercise year from the `Exercício:` metadata line
#' @noRd
finbra_year <- function(lines, call = caller_env()) {
  hits <- trimws(lines)[grepl("^Exerc\u00edcio:", trimws(lines))]
  if (length(hits) != 1L) {
    cli::cli_abort(
      "FINBRA file has no single `Exerc\u00edcio:` metadata line.",
      call = call
    )
  }
  digits <- regmatches(hits, regexpr("[0-9]{4}", hits))
  if (length(digits) == 0L) {
    cli::cli_abort(
      "No exercise year found in {.val {hits}}.",
      call = call
    )
  }
  return(as.integer(digits))
}

#' Parse one FINBRA data line into a tax-row tibble
#'
#' Returns NULL for non-tax rows. From the end of the line: the last
#' field is `Valor`, the second-to-last is `Identificador da Conta`, the
#' third-to-last is the quoted account name, and the fourth-to-last is
#' `Coluna`; the four leading fields (institution through population)
#' precede both. The account-name field may carry unescaped quotes or
#' even `;`.
#' @noRd
finbra_parse_line <- function(line, year, call = caller_env()) {
  fields <- strsplit(line, ";", fixed = TRUE)[[1L]]
  n <- length(fields)
  if (n < 8L) {
    # Continuation fragments of corrupted account names and short junk
    # lines can never be a tax row; tax rows keep exactly 8 fields.
    return(NULL)
  }

  code <- siconfi_clean_code(fields[n - 1L])
  tax <- siconfi_classify_code(code, year, call = call)
  if (is.na(tax)) {
    return(NULL)
  }

  if (n != 8L) {
    cli::cli_abort(
      "Tax row with unexpected layout ({n} fields instead of 8) for \\
       {.val {code}}.",
      call = call
    )
  }

  label <- trimws(gsub('"', "", fields[n - 3L], fixed = TRUE))
  return(tibble::tibble(
    year = year,
    code_muni = trimws(fields[2L]),
    abbrev_state = trimws(fields[3L]),
    institution = trimws(fields[1L]),
    tax = tax,
    value_kind = siconfi_value_kind(label, call = call),
    value = siconfi_parse_number(fields[n], call = call)
  ))
}

# SICONFI DCA API -------------------------------------------------------------

#' Parse `/dca` items into the FINBRA long form
#'
#' `items` holds one list per item (`jsonlite::fromJSON(simplifyVector =
#' FALSE)` outlines), with fields `exercicio`, `cod_ibge`, `uf`,
#' `instituicao`, `coluna`, `cod_conta`, `valor`. The API column labels
#' follow the 2014+ vocabulary for every year.
#' @keywords internal
parse_siconfi_dca <- function(items, call = caller_env()) {
  if (length(items) == 0L) {
    return(siconfi_long_columns())
  }

  parsed <- lapply(items, parse_dca_item, call = call)
  tax_rows <- parsed[!vapply(parsed, is.null, logical(1L))]

  if (length(tax_rows) == 0L) {
    return(siconfi_long_columns())
  }

  return(dplyr::bind_rows(tax_rows))
}

#' Parse one /dca item into a one-row long form (or drop non-tax rows)
#' @noRd
parse_dca_item <- function(item, call = caller_env()) {
  year <- as.integer(as.numeric(item$exercicio %||% NA_real_))
  code <- siconfi_clean_code(item$cod_conta %||% "")
  tax <- siconfi_classify_code(code, year, call = call)
  if (is.na(tax)) {
    return(NULL)
  }

  label <- trimws(item$coluna %||% "")
  raw_value <- item$valor
  if (is.null(raw_value) || length(raw_value) != 1L) {
    raw_value <- ""
  }

  return(tibble::tibble(
    year = year,
    code_muni = dca_code_muni(item$cod_ibge, call = call),
    abbrev_state = trimws(item$uf %||% ""),
    institution = trimws(item$instituicao %||% ""),
    tax = tax,
    value_kind = siconfi_value_kind(label, call = call),
    value = siconfi_parse_number(raw_value, call = call)
  ))
}

#' Seven-digit IBGE municipality code from a /dca item
#' @noRd
dca_code_muni <- function(cod_ibge, call = caller_env()) {
  if (is.null(cod_ibge)) {
    cli::cli_abort("Missing cod_ibge in a /dca item.", call = call)
  }
  numeric_code <- as.numeric(cod_ibge)
  if (length(numeric_code) != 1L || is.na(numeric_code)) {
    cli::cli_abort(
      "Malformed cod_ibge {.val {cod_ibge}} in a /dca item.",
      call = call
    )
  }
  code <- sprintf("%.0f", numeric_code)
  if (!grepl("^[0-9]{7}$", code)) {
    cli::cli_abort(
      "Malformed cod_ibge {.val {code}}: must be a 7-digit municipality code.",
      call = call
    )
  }
  return(code)
}

#' Build a /dca page URL
#' @noRd
siconfi_dca_url <- function(code_muni, year, offset) {
  # `no_anexo` carries a literal space, escaped as %20 per Tesouro's own
  # examples.
  paste0(
    "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca",
    "?an_exercicio=",
    year,
    "&no_anexo=DCA-Anexo%20I-C",
    "&id_ente=",
    code_muni,
    # One page per municipality-year in practice; pagination still follows
    # `hasMore` when an exercise somehow exceeds the limit (per the plan's
    # own working query).
    "&limit=10000",
    "&offset=",
    offset
  )
}

#' Perform the real HTTP GET for one /dca page, with retries
#' @noRd
siconfi_dca_request <- function(url, quiet = FALSE) {
  download_with_retry(
    fn = function() {
      response <- httr::GET(
        url = url,
        httr::user_agent(
          "realestatebr R package (https://github.com/viniciusoike/realestatebr)"
        )
      )
      httr::stop_for_status(response)
      text <- httr::content(response, as = "text", encoding = "UTF-8")
      return(jsonlite::fromJSON(text, simplifyVector = FALSE))
    },
    max_retries = 3,
    quiet = quiet,
    desc = "SICONFI DCA request"
  )
}

#' Fetch all /dca items for one municipality-year
#'
#' Follows pagination by advancing `offset` by the page's reported
#' `limit` while `hasMore` is true, and rejects a repeated page (the
#' server can resend a page instead of honouring the offset).
#'
#' @param request Injectable for tests: a callable taking a URL string
#'   and returning the parsed response body.
#' @keywords internal
fetch_siconfi_dca <- function(
  code_muni,
  year,
  request = NULL,
  call = caller_env()
) {
  request <- request %||% siconfi_dca_request
  code <- dca_code_muni(code_muni, call = call)

  offset <- 0L
  page <- request(siconfi_dca_url(code, year, offset))
  items <- page$items %||% list()

  while (isTRUE(page$hasMore)) {
    offset <- offset + (page$limit %||% length(items))
    next_page <- request(siconfi_dca_url(code, year, offset))
    if (identical(next_page$offset, page$offset)) {
      cli::cli_abort(
        "Repeated page: the SICONFI API sent {page$limit} rows twice for \\
         municipality {code} in {year}.",
        call = call
      )
    }
    page <- next_page
    items <- c(items, page$items %||% list())
  }

  return(items)
}

# Build the dataset -----------------------------------------------------------

#' Wide per-tax form of a parsed long form
#'
#' One row per code_muni x year x tax with `gross_revenue` and
#' `other_deductions` (NA when the row is absent); excluded-deduction
#' rows carry no value.
#' @noRd
siconfi_wide <- function(long) {
  if (nrow(long) == 0L) {
    return(tibble::tibble(
      code_muni = character(),
      year = integer(),
      tax = character(),
      gross_revenue = double(),
      other_deductions = double()
    ))
  }

  tax_rows <- dplyr::filter(long, .data$value_kind != "excluded_deduction")
  gross <- dplyr::select(
    dplyr::filter(tax_rows, .data$value_kind == "gross"),
    "code_muni",
    "year",
    "tax",
    gross_revenue = "value"
  )
  deductions <- dplyr::select(
    dplyr::filter(tax_rows, .data$value_kind == "deduction"),
    "code_muni",
    "year",
    "tax",
    other_deductions = "value"
  )

  return(dplyr::full_join(
    gross,
    deductions,
    by = c("code_muni", "year", "tax")
  ))
}

#' Build the published `siconfi_taxes` table
#'
#' `finbra` and `api` are parsed long forms (source `finbra` and `api`
#' respectively); `municipalities` holds the municipality universe as a
#' tibble with integer 7-digit `code_muni` and `abbrev_state`.
#' API rows replace FINBRA rows for the whole municipality-year so the
#' per-row `source` stays unambiguous. Non-reporters get one row per tax
#' with `reported = FALSE` and `NA` values. The net revenue is gross
#' minus deductions, rounded to cents, and stays `NA` whenever either
#' side is `NA`: missing deduction rows never prove zero.
#'
#' @keywords internal
build_siconfi_taxes <- function(
  finbra,
  api = NULL,
  municipalities,
  call = caller_env()
) {
  siconfi_check_long_form(finbra, "finbra", call = call)
  if (!is.null(api)) {
    siconfi_check_long_form(api, "api", call = call)
  }
  siconfi_check_municipalities(municipalities, call = call)

  finbra_wide <- siconfi_wide(finbra)
  api_wide <- if (is.null(api)) NULL else siconfi_wide(api)

  # Any row of the long form (including excluded deductions and rows
  # without values) proves the municipality reported in that year.
  api_reported <- if (is.null(api)) {
    character()
  } else {
    paste(api$code_muni, api$year)
  }
  finbra_reported <- setdiff(paste(finbra$code_muni, finbra$year), api_reported)

  # Whole municipality-years covered by the API replace FINBRA rows.
  finbra_wide <- dplyr::filter(
    finbra_wide,
    !(paste(.data$code_muni, .data$year) %in% api_reported)
  )
  wide <- dplyr::bind_rows(finbra_wide, api_wide %||% finbra_wide[NULL, ])

  years <- sort(unique(c(finbra$year, if (!is.null(api)) api$year)))
  universe <- dplyr::distinct(
    dplyr::mutate(
      as.data.frame(municipalities),
      code_muni = sprintf("%.0f", as.numeric(code_muni))
    )[c("code_muni", "abbrev_state")]
  )

  grid <- tidyr::crossing(
    tibble::tibble(
      code_muni = universe$code_muni,
      abbrev_state = universe$abbrev_state
    ),
    tibble::tibble(year = as.integer(years)),
    tibble::tibble(tax = c("iptu", "itbi"))
  )
  data <- dplyr::left_join(grid, wide, by = c("code_muni", "year", "tax"))

  keys <- paste(data$code_muni, data$year)
  data$reported <- keys %in% c(api_reported, finbra_reported)
  data$value_status <- dplyr::case_when(
    !data$reported ~ "non_reporter",
    !is.na(data$gross_revenue) ~ "observed",
    TRUE ~ "missing_tax_row"
  )
  data$source <- dplyr::case_when(
    !data$reported ~ NA_character_,
    keys %in% api_reported ~ "api",
    TRUE ~ "finbra"
  )

  data$net_revenue <- dplyr::if_else(
    is.na(data$gross_revenue) | is.na(data$other_deductions),
    NA_real_,
    round(data$gross_revenue - data$other_deductions, 2)
  )
  data$account_scope <- dplyr::if_else(
    data$year <= 2017L,
    "legacy_line",
    "tax_family"
  )

  data <- dplyr::mutate(
    data,
    code_muni = as.integer(.data$code_muni),
    year = as.integer(.data$year)
  )
  data <- dplyr::arrange(data, .data$code_muni, .data$year, .data$tax)
  return(dplyr::select(data, dplyr::all_of(siconfi_published_columns())))
}

#' Published column names in order
#' @noRd
siconfi_published_columns <- function() {
  c(
    "code_muni",
    "abbrev_state",
    "year",
    "tax",
    "reported",
    "value_status",
    "gross_revenue",
    "other_deductions",
    "net_revenue",
    "account_scope",
    "source"
  )
}

#' Internal guard: parsed long-form shape
#' @noRd
siconfi_check_long_form <- function(long, name, call = caller_env()) {
  if (!is.data.frame(long)) {
    cli::cli_abort(
      "{.arg {name}} must be a data frame of parsed tax rows.",
      call = call
    )
  }
  required <- c(
    "year",
    "code_muni",
    "abbrev_state",
    "institution",
    "tax",
    "value_kind",
    "value"
  )
  missing_cols <- setdiff(required, names(long))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "Parsed {.arg {name}} data is missing columns \\
       {.val {missing_cols}}.",
      call = call
    )
  }
  if (nrow(long) > 0L) {
    bad_kinds <- setdiff(
      unique(long$value_kind),
      c("gross", "deduction", "excluded_deduction")
    )
    if (length(bad_kinds) > 0L) {
      cli::cli_abort(
        "Parsed {.arg {name}} data has unknown value_kind values: \\
         {.val {bad_kinds}}.",
        call = call
      )
    }
  }
}

#' Internal guard: municipality-universe shape
#' @noRd
siconfi_check_municipalities <- function(municipalities, call = caller_env()) {
  if (!is.data.frame(municipalities)) {
    cli::cli_abort(
      "{.arg municipalities} must be a data frame with code_muni and \\
       abbrev_state.",
      call = call
    )
  }
  if (!all(c("code_muni", "abbrev_state") %in% names(municipalities))) {
    cli::cli_abort(
      "{.arg municipalities} needs code_muni and abbrev_state columns.",
      call = call
    )
  }
  codes <- as.character(municipalities$code_muni)
  bad <- !grepl("^[0-9]{7}$", codes)
  if (nrow(municipalities) > 0L && any(bad)) {
    cli::cli_abort(
      "{.arg municipalities} has non 7-digit code_muni values: \\
       {.val {head(unique(codes[bad]), 3L)}}.",
      call = call
    )
  }
}

# Validation ------------------------------------------------------------------

#' Validate the built `siconfi_taxes` table
#'
#' Checks the published schema (column names, order and types), integer
#' 7-digit municipality codes, and unique code_muni x year x tax keys.
#' @keywords internal
validate_siconfi_taxes <- function(data, call = caller_env()) {
  problems <- siconfi_schema_problems(data, siconfi_published_columns())
  if (length(problems) > 0L) {
    cli::cli_abort(
      c(
        "The siconfi_taxes data does not match the published schema.",
        "x" = "{problems}"
      ),
      call = call
    )
  }
  keys <- paste(data$code_muni, data$year, data$tax)
  if (anyDuplicated(keys) > 0L) {
    duplicated_key <- keys[keys %in% keys[duplicated(keys)]][[1L]]
    cli::cli_abort(
      "Found duplicate key {.val {duplicated_key}} in \\
       code_muni x year x tax.",
      call = call
    )
  }
  return(invisible(data))
}

#' Schema problems for the siconfi_taxes table
#'
#' Returns a character vector of problems (empty when the table conforms).
#' @noRd
siconfi_schema_problems <- function(data, expected_names) {
  type_specs <- list(
    "code_muni" = "integer",
    "year" = "integer",
    "gross_revenue" = "double",
    "other_deductions" = "double",
    "net_revenue" = "double"
  )
  if (!is.data.frame(data)) {
    return("the parsed table must be a data frame")
  }
  problems <- character(0L)
  if (!identical(names(data), expected_names)) {
    problems <- c(
      problems,
      sprintf(
        "expected schema %s, found %s",
        paste(expected_names, collapse = ", "),
        paste(names(data), collapse = ", ")
      )
    )
  }
  for (column in names(type_specs)) {
    if (column %in% names(data)) {
      actual <- typeof(data[[column]])
      if (actual != type_specs[[column]]) {
        problems <- c(
          problems,
          sprintf(
            "column %s must be %s, found %s",
            column,
            type_specs[[column]],
            actual
          )
        )
      }
    }
  }
  if ("code_muni" %in% names(data)) {
    codes <- sprintf("%.0f", as.numeric(data$code_muni))
    bad_codes <- !grepl("^[0-9]{7}$", codes)
    if (any(bad_codes)) {
      problems <- c(
        problems,
        sprintf(
          "code_muni must be 7-digit integers; got %s",
          data$code_muni[which(bad_codes)[1L]]
        )
      )
    }
  }
  if ("tax" %in% names(data)) {
    bad_tax <- setdiff(unique(data$tax), c("iptu", "itbi"))
    if (length(bad_tax) > 0L) {
      problems <- c(
        problems,
        sprintf(
          "unexpected tax values %s",
          paste(bad_tax, collapse = ", ")
        )
      )
    }
  }
  return(problems)
}
