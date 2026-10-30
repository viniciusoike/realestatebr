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
# rows. `current_revenue` and `tax_revenue` hold the municipality-year
# context totals (Receitas Correntes and Impostos, Taxas e Contribuições
# de Melhoria, both gross realized), verified per vintage in the plan.
.siconfi_vintages <- list(
  list(
    start = 2013L,
    end = 2017L,
    family = "RO1.1.1.2.",
    iptu = "RO1.1.1.2.02.00.00",
    itbi = "RO1.1.1.2.08.00.00",
    current_revenue = "RO1.0.0.0.00.00.00",
    tax_revenue = "RO1.1.0.0.00.00.00",
    ignore_re = "^RO1\\.1\\.1\\.2\\.[0-9]{2}\\.[0-9]{2}\\.[0-9]{2}$"
  ),
  list(
    start = 2018L,
    end = 2021L,
    family = "RO1.1.1.8.",
    iptu = "RO1.1.1.8.01.1.0",
    itbi = "RO1.1.1.8.01.4.0",
    current_revenue = "RO1.0.0.0.00.0.0",
    tax_revenue = "RO1.1.0.0.00.0.0",
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
    current_revenue = "RO1.0.0.0.00.0.0",
    tax_revenue = "RO1.1.0.0.00.0.0",
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

#' Classify one SICONFI context account identifier
#'
#' Returns `"current_revenue"` (Receitas Correntes), `"tax_revenue"`
#' (Impostos, Taxas e Contribuições de Melhoria), or NA for every other
#' account. Both totals are taken from the gross-realized column only.
#' @noRd
siconfi_context_kind <- function(code, year, call = caller_env()) {
  vintage <- siconfi_vintage_for_year(year, call = call)
  if (identical(code, vintage$current_revenue)) {
    return("current_revenue")
  }
  if (identical(code, vintage$tax_revenue)) {
    return("tax_revenue")
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
#' Any SICONFI account row (tax or context) reaching an unknown label
#' aborts with the offending label in the message.
#' @noRd
siconfi_value_kind <- function(label, call = caller_env()) {
  kind_index <- match(label, names(.siconfi_label_kinds))
  if (is.na(kind_index)) {
    cli::cli_abort(
      "Unknown column label {.val {label}} on an account row.",
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
#'   `tax`, `value_kind`, `value`), carrying the attribute `reporters`:
#'   character keys `<code_muni> <year>` of every municipality that has a
#'   valid data line in the file (any account), not only tax rows; and
#'   the attribute `context`: one tibble row per municipality-year with
#'   `current_revenue` and `tax_revenue` (the gross realized values of
#'   the Current Revenue and Taxes, Fees and Contributions accounts). The
#'   file's `População` field is ignored: population comes from IBGE (see
#'   `fetch_siconfi_population()`).
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
  rows <- lapply(parsed, `[[`, "row")
  tax_rows <- rows[!vapply(rows, is.null, logical(1L))]

  if (length(tax_rows) == 0L) {
    cli::cli_abort(
      "No IPTU or ITBI rows found in FINBRA file {.path {path}}.",
      call = call
    )
  }

  codes <- vapply(parsed, `[[`, character(1L), "code")
  reporter_keys <- paste(
    unique(codes[!is.na(codes)]),
    year
  )
  long <- dplyr::bind_rows(tax_rows)
  attr(long, "reporters") <- reporter_keys
  attr(long, "context") <- siconfi_build_context(
    context_rows = Filter(
      Negate(is.null),
      lapply(parsed, `[[`, "context")
    ),
    call = call
  )
  return(long)
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

#' Parse one FINBRA data line
#'
#' Returns a list with `code` (the municipality's 7-digit IBGE code when
#' the line is a full data record, else NA — used for the reporters set),
#' `context` (a one-row context tibble for context-account rows carrying a
#' gross-realized value, else NULL) and `row` (a one-row long-form tibble
#' for tax rows, NULL for non-tax rows). From the end of the line: the
#' last field is `Valor`, the second-to-last is `Identificador da Conta`,
#' the third-to-last is the quoted account name, and the fourth-to-last is
#' `Coluna`; the leading fields (institution through population) precede
#' both. The account-name field may carry unescaped quotes or even `;`.
#' The `População` field is not read (population comes from IBGE; see
#' `fetch_siconfi_population()`).
#' @noRd
finbra_parse_line <- function(line, year, call = caller_env()) {
  fields <- strsplit(line, ";", fixed = TRUE)[[1L]]
  n <- length(fields)
  if (n < 8L) {
    # Continuation fragments of corrupted account names and short junk
    # lines can never be a tax row; abort when the fragment still carries
    # one of the year's tax identifiers: dropping a truncated tax row
    # silently would publish a wrong value.
    vintage <- siconfi_vintage_for_year(year, call = call)
    tax_codes <- c(vintage$iptu, vintage$itbi)
    hits <- tax_codes[vapply(
      tax_codes,
      \(code) grepl(code, line, fixed = TRUE),
      logical(1L)
    )]
    if (length(hits) > 0L) {
      cli::cli_abort(
        "FINBRA line fragment carries the tax identifier {.val {hits[[1]]}} \\
         with only {n} fields; tax rows keep exactly 8 fields, so a \\
         truncated tax row aborts instead of silently vanishing.",
        call = call
      )
    }
    return(list(
      code = NA_character_,
      context = NULL,
      row = NULL
    ))
  }

  code_muni <- trimws(fields[2L])
  reporter <- if (grepl("^[0-9]{7}$", code_muni)) code_muni else NA_character_

  code <- siconfi_clean_code(fields[n - 1L])
  tax <- siconfi_classify_code(code, year, call = call)
  if (is.na(tax)) {
    context <- finbra_context_row(fields, code, code_muni, year, call = call)
    return(list(
      code = reporter,
      context = context,
      row = NULL
    ))
  }

  if (n != 8L) {
    cli::cli_abort(
      "Tax row with unexpected layout ({n} fields instead of 8) for \\
       {.val {code}}.",
      call = call
    )
  }

  label <- trimws(gsub('"', "", fields[n - 3L], fixed = TRUE))
  row <- tibble::tibble(
    year = year,
    code_muni = code_muni,
    abbrev_state = trimws(fields[3L]),
    institution = trimws(fields[1L]),
    tax = tax,
    value_kind = siconfi_value_kind(label, call = call),
    value = siconfi_parse_number(fields[n], call = call)
  )
  return(list(
    code = reporter,
    context = NULL,
    row = row
  ))
}

#' Context tibble for a context-account line (gross realized value only)
#' @noRd
finbra_context_row <- function(
  fields,
  code,
  code_muni,
  year,
  call = caller_env()
) {
  kind <- siconfi_context_kind(code, year, call = call)
  if (is.na(kind)) {
    return(NULL)
  }
  n <- length(fields)
  label <- trimws(gsub('"', "", fields[n - 3L], fixed = TRUE))
  value_kind <- siconfi_value_kind(label, call = call)
  if (value_kind != "gross") {
    return(NULL)
  }
  value <- siconfi_parse_number(fields[n], call = call)
  return(tibble::tibble(
    code_muni = code_muni,
    year = year,
    current_revenue = if (identical(kind, "current_revenue")) {
      value
    } else {
      NA_real_
    },
    tax_revenue = if (identical(kind, "tax_revenue")) value else NA_real_
  ))
}

#' Aggregate the parsed municipality-year context
#'
#' `context_rows` are one-row tibbles from context-account lines. Returns
#' one tibble per municipality-year with `current_revenue` and
#' `tax_revenue`; conflicting values within a municipality-year abort
#' instead of being silently deduplicated.
#' @noRd
siconfi_build_context <- function(
  context_rows,
  call = caller_env()
) {
  context <- siconfi_context_empty()

  rows <- dplyr::bind_rows(context_rows)
  if (nrow(rows) > 0L) {
    conflicts <- rows |>
      dplyr::group_by(.data$code_muni, .data$year) |>
      dplyr::summarise(
        dplyr::across(
          c("current_revenue", "tax_revenue"),
          \(values) dplyr::n_distinct(values, na.rm = TRUE)
        ),
        .groups = "drop"
      )
    off <- conflicts[
      conflicts$current_revenue > 1L |
        conflicts$tax_revenue > 1L,
    ]
    if (nrow(off) > 0L) {
      cli::cli_abort(
        "Conflicting context values for municipality-year \\
         {.val {paste(off$code_muni, off$year)[[1L]]}}.",
        call = call
      )
    }
    wide <- rows |>
      dplyr::group_by(.data$code_muni, .data$year) |>
      dplyr::summarise(
        dplyr::across(
          c("current_revenue", "tax_revenue"),
          \(values) {
            values <- values[!is.na(values)]
            if (length(values) > 0L) values[[1L]] else NA_real_
          }
        ),
        .groups = "drop"
      )
    context <- wide
  }
  return(dplyr::arrange(context, .data$code_muni, .data$year))
}

#' Empty context tibble shared by all parsers
#' @noRd
siconfi_context_empty <- function() {
  return(tibble::tibble(
    code_muni = character(),
    year = integer(),
    current_revenue = double(),
    tax_revenue = double()
  ))
}

#' Context attribute of a parsed long form (empty when absent)
#' @noRd
siconfi_context_attr <- function(long) {
  return(attr(long, "context") %||% siconfi_context_empty())
}

# SICONFI DCA API -------------------------------------------------------------

#' Parse `/dca` items into the FINBRA long form
#'
#' `items` holds one list per item (`jsonlite::fromJSON(simplifyVector =
#' FALSE)` outlines), with fields `exercicio`, `cod_ibge`, `uf`,
#' `instituicao`, `coluna`, `cod_conta`, `valor`. The API column labels
#' follow the 2014+ vocabulary for every year. The result carries the
#' attribute `reporters`: `<code_muni> <exercicio>` keys of every item,
#' any account; and the attribute `context` from the current-revenue and
#' tax-revenue items (gross column only). The API's `populacao` field is
#' ignored: population comes from IBGE (see
#' `fetch_siconfi_population()`).
#' @keywords internal
parse_siconfi_dca <- function(items, call = caller_env()) {
  if (length(items) == 0L) {
    long <- siconfi_long_columns()
    attr(long, "reporters") <- character()
    attr(long, "context") <- siconfi_context_empty()
    return(long)
  }

  parsed <- lapply(items, parse_dca_item, call = call)
  codes <- vapply(parsed, `[[`, character(1L), "code")
  years <- vapply(parsed, `[[`, numeric(1L), "year")

  rows <- lapply(parsed, `[[`, "row")
  tax_rows <- rows[!vapply(rows, is.null, logical(1L))]

  long <- if (length(tax_rows) == 0L) {
    siconfi_long_columns()
  } else {
    dplyr::bind_rows(tax_rows)
  }
  attr(long, "reporters") <- unique(paste(codes, years))
  attr(long, "context") <- siconfi_build_context(
    context_rows = Filter(
      Negate(is.null),
      lapply(parsed, `[[`, "context")
    ),
    call = call
  )
  return(long)
}

#' Parse one /dca item
#'
#' Returns a list with `code` (the item's IBGE code), `year`, `row` (a
#' one-row long form for tax items, NULL for non-tax items) and
#' `context` (a one-row context tibble for context-account items in the
#' gross column, NULL otherwise). The item's `populacao` field is
#' ignored: population comes from IBGE (see
#' `fetch_siconfi_population()`).
#' @noRd
parse_dca_item <- function(item, call = caller_env()) {
  year <- as.integer(as.numeric(item$exercicio %||% NA_real_))
  code_muni <- dca_code_muni(item$cod_ibge, call = call)
  code <- siconfi_clean_code(item$cod_conta %||% "")
  tax <- siconfi_classify_code(code, year, call = call)
  context <- NULL
  if (is.na(tax)) {
    kind <- siconfi_context_kind(code, year, call = call)
    if (!is.na(kind)) {
      label <- trimws(item$coluna %||% "")
      value_kind <- siconfi_value_kind(label, call = call)
      if (identical(value_kind, "gross")) {
        raw_value <- item$valor
        if (is.null(raw_value) || length(raw_value) != 1L) {
          raw_value <- ""
        }
        value <- siconfi_parse_number(raw_value, call = call)
        context <- tibble::tibble(
          code_muni = code_muni,
          year = year,
          current_revenue = if (identical(kind, "current_revenue")) {
            value
          } else {
            NA_real_
          },
          tax_revenue = if (identical(kind, "tax_revenue")) {
            value
          } else {
            NA_real_
          }
        )
      }
    }
  }
  row <- NULL
  if (!is.na(tax)) {
    label <- trimws(item$coluna %||% "")
    raw_value <- item$valor
    if (is.null(raw_value) || length(raw_value) != 1L) {
      raw_value <- ""
    }
    row <- tibble::tibble(
      year = year,
      code_muni = code_muni,
      abbrev_state = trimws(item$uf %||% ""),
      institution = trimws(item$instituicao %||% ""),
      tax = tax,
      value_kind = siconfi_value_kind(label, call = call),
      value = siconfi_parse_number(raw_value, call = call)
    )
  }
  return(list(code = code_muni, year = year, context = context, row = row))
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

#' Minimum spacing between the starts of two SICONFI requests
#'
#' The API specification caps traffic at one request per second; retry
#' backoff adds on top. Shared by the first page, follow-up pages and
#' retries.
#' @noRd
siconfi_pace <- local({
  last <- -Inf
  function() {
    wait <- 1.05 - as.double(difftime(Sys.time(), last, units = "secs"))
    if (wait > 0) {
      Sys.sleep(wait)
    }
    last <<- Sys.time()
    return(invisible(TRUE))
  }
})

#' Perform the real HTTP GET for one /dca page, with retries
#' @noRd
siconfi_dca_request <- function(url, quiet = FALSE) {
  download_with_retry(
    fn = function() {
      siconfi_pace()
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

# Upper bound on the /dca pages fetched for a single municipality-year;
# every past build fits in one 10,000-item page, so exceeding this cap
# means pagination is misdirected, never legitimate.
SICONFI_MAX_PAGES <- 50L

#' Check one /dca page for completeness
#'
#' Rejects a page whose declared `count` does not match the carried items
#' (an inconsistent or truncated response) and one whose `offset` does
#' not match the requested offset (a resent or misdirected page).
#' Returns the page's items.
#' @noRd
siconfi_check_dca_page <- function(
  page,
  offset,
  code_muni,
  year,
  call = caller_env()
) {
  items <- page$items %||% list()
  expected_count <- as.integer(page$count %||% length(items))
  if (expected_count != length(items)) {
    cli::cli_abort(
      c(
        "Inconsistent SICONFI response for municipality {code_muni} in \\
         {year}.",
        "x" = "The response declares count {.val {expected_count}} but \\
               carries {.val {length(items)}} item{?s}."
      ),
      call = call
    )
  }
  page_offset <- as.integer(page$offset %||% offset)
  if (page_offset != offset) {
    cli::cli_abort(
      "The SICONFI API returned offset {.val {page_offset}} when \\
       {.val {offset}} was requested for municipality {code_muni} in \\
       {year}; the page may have been resent or misdirected.",
      call = call
    )
  }
  return(items)
}

#' Fetch all /dca items for one municipality-year
#'
#' Follows pagination by advancing `offset` by the page's reported
#' `limit` while `hasMore` is true; every page must carry its declared
#' `count` and the requested `offset`, and the number of pages is
#' capped: a truncated, resent or misdirected response aborts instead of
#' being silently parsed. The default `request` also paces itself at at
#' most one request per second inside the retry loop.
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
  code_muni <- code

  offset <- 0L
  page <- request(siconfi_dca_url(code, year, offset))
  items <- siconfi_check_dca_page(page, offset, code_muni, year, call = call)

  pages <- 1L
  while (isTRUE(page$hasMore)) {
    pages <- pages + 1L
    if (pages > SICONFI_MAX_PAGES) {
      cli::cli_abort(
        "The SICONFI API exceeded {.val {SICONFI_MAX_PAGES}} pages for \\
         municipality {code} in {year}; the pagination is misdirected.",
        call = call
      )
    }
    offset <- offset + as.integer(page$limit %||% length(items))
    page <- request(siconfi_dca_url(code, year, offset))
    items <- c(
      items,
      siconfi_check_dca_page(page, offset, code_muni, year, call = call)
    )
  }

  return(items)
}

# IBGE population -------------------------------------------------------------

#' Resident population by municipality-year from IBGE
#'
#' The estimates come from SIDRA table 6579 (variable 9324, População
#' residente estimada, the requested years only, localities N6[all];
#' table and variable verified 25 Oct 2026), the 2022 Census count from
#' table 4709 (variable 93, single 2022 period), and 2023 gets a linear
#' midpoint between the 2022 Census and the 2024 estimate (ties round to
#' even, R's `round()`). Dataset years without a figure stay absent: the
#' builder fills them with NA. `fetch` is injectable for tests: the
#' aggregate fetcher called as `fetch(aggregate, variables, periods,
#' localities)`.
#' @param years Exercise years the dataset covers.
#' @return A tibble `code_muni` (character, 7 digits), `year` (integer),
#'   `population` (integer), `population_source` ("estimate", "census",
#'   "interpolated").
#' @keywords internal
fetch_siconfi_population <- function(
  years,
  fetch = download_ibge_aggregate,
  call = caller_env()
) {
  years <- sort(unique(as.integer(years)))
  empty <- tibble::tibble(
    code_muni = character(),
    year = integer(),
    population = integer(),
    population_source = character()
  )
  if (length(years) == 0L) {
    return(empty)
  }

  estimates <- fetch(
    aggregate = "6579",
    variables = "9324",
    periods = as.character(years),
    localities = "N6[all]",
    # IBGE answers HTTP 500 above ~8 periods on this table when the query
    # carries the whole N6[all] municipality universe; small chunks keep
    # every request under the limit.
    chunk_size = 5L
  )
  census <- if (2022L %in% years) {
    fetch(
      aggregate = "4709",
      variables = "93",
      periods = "2022",
      localities = "N6[all]"
    )
  } else {
    NULL
  }

  population <- dplyr::bind_rows(
    siconfi_population_rows(estimates, "estimate", years),
    siconfi_population_rows(census, "census", years),
    empty
  )
  population <- siconfi_interpolate_population(population)

  # Guard against a silently thin table: every requested year needs a
  # universe-sized fetch. 2023 is only produced by the interpolation, so
  # it is checked unless either anchor year was not requested.
  checked_years <- years
  if (!(2022L %in% years) || !(2024L %in% years)) {
    checked_years <- setdiff(checked_years, 2023L)
  }
  counts <- dplyr::summarise(
    dplyr::filter(population, !is.na(.data$population)),
    municipalities = dplyr::n_distinct(.data$code_muni),
    .by = "year"
  )
  thin <- counts[
    counts$year %in% checked_years & counts$municipalities < 5000L,
  ]
  if (nrow(thin) > 0L) {
    details <- paste0(thin$year, " (", thin$municipalities, " municipalities)")
    cli::cli_abort(
      c(
        "The IBGE population fetch came back thin.",
        "x" = "{.val {details}} carry fewer than 5000 municipalities with \\
               population; the SIDRA table or the query likely changed."
      )
    )
  }
  cli::cli_inform(
    "IBGE population: {.val {nrow(population)}} municipality-years for \\
     {.val {years}} after the 2023 interpolation (estimates from table \\
     6579, the 2022 Census from table 4709)."
  )
  return(population)
}

#' Population tibble from one fetch result
#'
#' `dat` is a `download_ibge_aggregate()` result; only the requested
#' years are kept and a missing value skips the row.
#' @noRd
siconfi_population_rows <- function(dat, source, years) {
  if (is.null(dat) || nrow(dat) == 0L) {
    return(tibble::tibble(
      code_muni = character(),
      year = integer(),
      population = integer(),
      population_source = character()
    ))
  }
  keep <- dat[as.integer(dat$period) %in% years & !is.na(dat$value), ]
  return(tibble::tibble(
    code_muni = sprintf("%.0f", as.numeric(keep$geography_code)),
    year = as.integer(keep$period),
    population = as.integer(round(keep$value)),
    population_source = source
  ))
}

#' Fill 2023 with the linear midpoint of the 2022 and 2024 population
#'
#' Pure: `population` holds code_muni/year/population rows (any source
#' labels); returns the input plus one 2023 row per municipality, with
#' NA population and NA `population_source` when either anchor is
#' missing. Ties round to even (R's `round()`).
#' @noRd
siconfi_interpolate_population <- function(
  population,
  call = caller_env()
) {
  population$population <- as.integer(population$population)
  anchors <- population[
    population$year %in% c(2022L, 2024L),
    c("code_muni", "year", "population"),
    drop = FALSE
  ]
  census <- anchors[anchors$year == 2022L, c("code_muni", "population")]
  names(census)[[2L]] <- "population_2022"
  estimate <- anchors[anchors$year == 2024L, c("code_muni", "population")]
  names(estimate)[[2L]] <- "population_2024"
  interpolated <- dplyr::full_join(census, estimate, by = "code_muni") |>
    dplyr::mutate(
      year = 2023L,
      population = as.integer(round(
        (.data$population_2022 + .data$population_2024) / 2
      )),
      population_source = dplyr::if_else(
        !is.na(.data$population_2022) & !is.na(.data$population_2024),
        "interpolated",
        NA_character_
      )
    ) |>
    dplyr::select("code_muni", "year", "population", "population_source")
  return(dplyr::bind_rows(population, interpolated))
}

#' Guard and normalize the injected population tibble
#'
#' Accepts character or integer 7-digit `code_muni`; NULL becomes an
#' empty tibble (every population published as NA).
#' @noRd
siconfi_check_population <- function(population, call = caller_env()) {
  if (is.null(population)) {
    return(tibble::tibble(
      code_muni = character(),
      year = integer(),
      population = integer(),
      population_source = character()
    ))
  }
  required <- c("code_muni", "year", "population", "population_source")
  if (!is.data.frame(population) || !all(required %in% names(population))) {
    cli::cli_abort(
      "{.arg population} must be a data frame with columns \\
       {.val {required}}.",
      call = call
    )
  }
  population <- population[required]
  population$code_muni <- sprintf("%.0f", as.numeric(population$code_muni))
  population$year <- as.integer(population$year)
  population$population <- as.integer(population$population)
  population$population_source <- as.character(population$population_source)
  return(population)
}

# Build the dataset -----------------------------------------------------------

#' Wide per-tax form of a parsed long form
#'
#' One row per code_muni x year x tax with `gross_revenue` and
#' `other_deductions` (NA when the row is absent); excluded-deduction
#' rows carry no value. `deductions_reported` records whether the
#' source carried a deduction row; it is NA only for keys absent from
#' the long form (added later by the grid fill).
#' @noRd
siconfi_wide <- function(long) {
  if (nrow(long) == 0L) {
    return(tibble::tibble(
      code_muni = character(),
      year = integer(),
      tax = character(),
      gross_revenue = double(),
      other_deductions = double(),
      deductions_reported = logical()
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

  wide <- dplyr::full_join(
    gross,
    deductions,
    by = c("code_muni", "year", "tax")
  )
  wide$deductions_reported <- !is.na(wide$other_deductions)
  return(wide)
}

#' Reporter keys of a parsed long form
#'
#' The attribute `reporters` holds `<code_muni> <year>` keys of every
#' municipality that filed (any account); without it the keys fall back
#' to the tax rows of the long form.
#' @noRd
siconfi_reporter_keys <- function(long) {
  keys <- attr(long, "reporters")
  if (is.null(keys)) {
    return(unique(paste(long$code_muni, long$year)))
  }
  return(unique(keys))
}

#' Years represented by reporter keys, plus the tax rows' own years
#' @noRd
reporter_years <- function(keys, fallback_years) {
  key_years <- as.integer(sub("^.* ", "", keys))
  return(unique(c(fallback_years, key_years)))
}

#' Build the published `siconfi_taxes` table
#'
#' `finbra` and `api` are parsed long forms (source `finbra` and `api`
#' respectively); `municipalities` holds the municipality universe as a
#' tibble with integer 7-digit `code_muni` and `abbrev_state`. `population`
#' holds the IBGE municipality-year population as a tibble (`code_muni`,
#' `year`, `population`, `population_source`); NULL publishes all NA.
#' API rows replace FINBRA rows for the whole municipality-year so the
#' per-row `source` stays unambiguous. Non-reporters get one row per tax
#' with `reported = FALSE` and NA tax and revenue values (population does
#' not depend on reporting). A gross row with no deduction
#' row in the source counts the deduction as zero: `other_deductions`
#' becomes 0, the net is computed, and `deductions_reported` marks the
#' assumption (FALSE assumed, TRUE observed, NA when there is no gross
#' row). Keys with a deduction row but no gross row keep `gross_revenue`
#' and `net_revenue` NA.
#'
#' @keywords internal
build_siconfi_taxes <- function(
  finbra,
  api = NULL,
  municipalities,
  population = NULL,
  call = caller_env()
) {
  siconfi_check_long_form(finbra, "finbra", call = call)
  if (!is.null(api)) {
    siconfi_check_long_form(api, "api", call = call)
  }
  siconfi_check_municipalities(municipalities, call = call)
  population <- siconfi_check_population(population, call = call)

  finbra_wide <- siconfi_wide(finbra)
  api_wide <- if (is.null(api)) NULL else siconfi_wide(api)

  # Reporting keys: any valid account proves the municipality filed in
  # that year (including municipalities with no IPTU/ITBI row); without
  # the attribute the keys fall back to the tax rows.
  finbra_reporters <- siconfi_reporter_keys(finbra)
  api_reporters <- if (is.null(api)) {
    character()
  } else {
    siconfi_reporter_keys(api)
  }

  # Whole municipality-years covered by the API replace FINBRA rows; an
  # API response with zero items declares no reporters and keeps FINBRA.
  api_covered <- union(
    if (is.null(api)) character() else paste(api$code_muni, api$year),
    api_reporters
  )
  finbra_reports_kept <- setdiff(finbra_reporters, api_covered)

  finbra_wide <- dplyr::filter(
    finbra_wide,
    !(paste(.data$code_muni, .data$year) %in% api_covered)
  )
  wide <- dplyr::bind_rows(finbra_wide, api_wide %||% finbra_wide[NULL, ])

  finbra_years <- reporter_years(finbra_reporters, finbra$year)
  api_years <- reporter_years(api_reporters, if (!is.null(api)) api$year)
  years <- sort(unique(c(finbra$year, api_years, finbra_years)))
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

  # Municipality-year context: the two revenue totals are repeated on
  # both tax rows, kept from one source per municipality-year (covered by
  # the API, they take the API values, dropped from FINBRA; else the
  # FINBRA values; a reporting municipality without the account lines
  # keeps NA, never zero). Population is independent of SICONFI
  # reporting: the injected IBGE tibble joins the grid by
  # municipality-year and fills reporter and non-reporter rows alike;
  # missing figures publish NA with NA population_source.
  finbra_context_revenue <- dplyr::filter(
    siconfi_context_attr(finbra),
    !(paste(.data$code_muni, .data$year) %in% api_covered)
  )
  api_context <- dplyr::filter(
    siconfi_context_attr(api),
    !is.na(.data$current_revenue) | !is.na(.data$tax_revenue)
  )
  revenue <- dplyr::bind_rows(finbra_context_revenue, api_context)
  data <- dplyr::left_join(data, revenue, by = c("code_muni", "year"))
  data <- dplyr::left_join(data, population, by = c("code_muni", "year"))

  keys <- paste(data$code_muni, data$year)
  data$reported <- keys %in% c(finbra_reports_kept, api_reporters)
  data$value_status <- dplyr::case_when(
    !data$reported ~ "non_reporter",
    !is.na(data$gross_revenue) ~ "observed",
    TRUE ~ "missing_tax_row"
  )
  data$source <- dplyr::case_when(
    !data$reported ~ NA_character_,
    keys %in% api_covered ~ "api",
    TRUE ~ "finbra"
  )

  # Gross rows without a deduction row: the deduction is assumed zero,
  # never missing. `deductions_reported` records the assumption (FALSE),
  # TRUE when the source carried a deduction row, NA when there is no
  # gross row. Deduction-only keys keep their observed deduction and NA
  # gross/net.
  data$other_deductions <- dplyr::if_else(
    is.na(data$other_deductions) & !is.na(data$gross_revenue),
    0,
    data$other_deductions
  )
  data$net_revenue <- dplyr::if_else(
    is.na(data$gross_revenue),
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
    "population",
    "population_source",
    "current_revenue",
    "tax_revenue",
    "tax",
    "reported",
    "value_status",
    "gross_revenue",
    "other_deductions",
    "deductions_reported",
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
       {.val {utils::head(unique(codes[bad]), 3L)}}.",
      call = call
    )
  }
}

# Validation ------------------------------------------------------------------

#' Validate the built `siconfi_taxes` table
#'
#' Checks the published schema (column names, order and types for every
#' column), integer 7-digit municipality codes, unique code_muni x year x
#' tax keys, the documented `tax`, `value_status`, `account_scope` and
#' `population_source` domains, NA values and source on non-reporter rows
#' (population is exempt: it is independent of reporting, with its source
#' NA exactly when it is NA), and the gross-minus-deductions net identity.
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
#' Returns a character vector of problems (empty when the table conforms):
#' column names and order, every published column's type, integer 7-digit
#' municipality codes, the documented `tax`, `value_status`,
#' `account_scope` and `population_source` domains, NA values and source
#' on non-reporter rows, `population_source` NA exactly when `population`
#' is NA, and `net_revenue = gross_revenue - other_deductions` to the cent
#' wherever both exist.
#' @noRd
siconfi_schema_problems <- function(data, expected_names) {
  type_specs <- list(
    "code_muni" = "integer",
    "abbrev_state" = "character",
    "year" = "integer",
    "population" = "integer",
    "population_source" = "character",
    "current_revenue" = "double",
    "tax_revenue" = "double",
    "tax" = "character",
    "reported" = "logical",
    "value_status" = "character",
    "gross_revenue" = "double",
    "other_deductions" = "double",
    "deductions_reported" = "logical",
    "net_revenue" = "double",
    "account_scope" = "character",
    "source" = "character"
  )
  domains <- list(
    "tax" = c("iptu", "itbi"),
    "value_status" = c("observed", "missing_tax_row", "non_reporter"),
    "account_scope" = c("legacy_line", "tax_family"),
    "source" = c("finbra", "api"),
    "population_source" = c("estimate", "census", "interpolated")
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
  if ("code_muni" %in% names(data) && nrow(data) > 0L) {
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
  for (column in names(domains)) {
    if (column %in% names(data) && nrow(data) > 0L) {
      bad_domain <- setdiff(
        unique(data[[column]]),
        c(domains[[column]], NA)
      )
      if (length(bad_domain) > 0L) {
        problems <- c(
          problems,
          sprintf(
            "unexpected %s values %s",
            column,
            paste(bad_domain, collapse = ", ")
          )
        )
      }
    }
  }
  if ("reported" %in% names(data)) {
    if (anyNA(data$reported)) {
      problems <- c(
        problems,
        "reported must be TRUE or FALSE; NA is not a published value"
      )
    } else if (nrow(data) > 0L) {
      non_reported <- which(!data$reported)
      for (column in c(
        "current_revenue",
        "tax_revenue",
        "gross_revenue",
        "other_deductions",
        "deductions_reported",
        "net_revenue",
        "source"
      )) {
        leaked <- which(!is.na(data[[column]][non_reported]))
        if (length(leaked) > 0L) {
          problems <- c(
            problems,
            sprintf(
              "non-reporter rows must keep %s NA; got %s",
              column,
              paste(
                utils::head(data[[column]][non_reported][leaked], 3L),
                collapse = ", "
              )
            )
          )
        }
      }
    }
  }
  if (
    all(c("population", "population_source") %in% names(data)) &&
      nrow(data) > 0L
  ) {
    off <- is.na(data$population) != is.na(data$population_source)
    if (any(off)) {
      bad <- which(off)[[1L]]
      problems <- c(
        problems,
        sprintf(
          paste0(
            "population_source must be NA exactly when population is NA,",
            "; first at code_muni %s year %s tax %s"
          ),
          sprintf("%.0f", data$code_muni[bad]),
          data$year[bad],
          data$tax[bad]
        )
      )
    }
  }
  numeric_columns <- all(vapply(
    c("gross_revenue", "other_deductions", "net_revenue"),
    \(column) {
      column %in% names(data) && is.double(data[[column]])
    },
    logical(1L)
  ))
  if (
    "deductions_reported" %in% names(data) && numeric_columns && nrow(data) > 0L
  ) {
    both <- which(
      !is.na(data$deductions_reported) & !is.na(data$net_revenue)
    )
    if (length(both) > 0L) {
      expected_net <- round(
        data$gross_revenue[both] - data$other_deductions[both],
        2
      )
      off <- abs(data$net_revenue[both] - expected_net) > 0.005
      if (any(off)) {
        first <- which(off)[1L]
        problems <- c(
          problems,
          sprintf(
            paste0(
              "net_revenue must equal gross_revenue minus other_deductions",
              " to the cent; %s row(s) are off, first at code_muni %s",
              " year %s tax %s"
            ),
            sum(off),
            data$code_muni[both[first]],
            data$year[both[first]],
            data$tax[both[first]]
          )
        )
      }
    }
  }
  return(problems)
}
