# Build the `siconfi_taxes` release snapshot ----
#
# Maintainer script (see data-raw/siconfi/dataset-plan.md for the design).
# It reads the FINBRA "Receitas Orçamentárias (Anexo I-C)" bulk ZIPs from a
# local directory that is never committed, optionally refreshes the latest
# years from the SICONFI `/dca` API with per-municipality-year disk
# checkpoints and at most one request per second, then builds, validates
# and writes the release-ready `siconfi_taxes.rds` plus a coverage
# manifest.
#
# Run from the package root:
#
#   Rscript data-raw/siconfi/build_snapshot.R
#     # full build: FINBRA history + a refresh of the two latest years
#   Rscript -e 'source("data-raw/siconfi/build_snapshot.R"); \
#     build_siconfi_snapshot(api_years = integer(), output_dir = "/tmp/x")'
#     # FINBRA-only build (no API traffic)

# Constants ----

SICONFI_ENTES_URL <- "https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000" # nolint

SICONFI_INTERNALS <- c(
  "read_finbra_file",
  "parse_siconfi_dca",
  "fetch_siconfi_dca",
  "build_siconfi_taxes",
  "validate_siconfi_taxes",
  "download_with_retry"
)

# Distinct reporters per year in the FINBRA bulk files (verified 23 Oct
# 2026; see the plan and its 2014 caveat). The coverage gate warns when a
# build deviates far from these counts; it never blocks silently.
SICONFI_PLAN_MUNIS <- c(
  "2013" = 5481L,
  "2014" = 5191L,
  "2015" = 5440L,
  "2016" = 5442L,
  "2017" = 5556L,
  "2018" = 5536L,
  "2019" = 5553L,
  "2020" = 5559L,
  "2021" = 5562L,
  "2022" = 5557L,
  "2023" = 5557L,
  "2024" = 5546L,
  "2025" = 5502L
)

# IBGE state codes keyed by the two leading municipality-code digits; the
# offline fallback for `abbrev_state` should `/entes` ever drop `uf`.
SICONFI_STATE_CODES <- c(
  "11" = "RO",
  "12" = "AC",
  "13" = "AM",
  "14" = "RR",
  "15" = "PA",
  "16" = "AP",
  "17" = "TO",
  "21" = "MA",
  "22" = "PI",
  "23" = "CE",
  "24" = "RN",
  "25" = "PB",
  "26" = "PE",
  "27" = "AL",
  "28" = "SE",
  "29" = "BA",
  "31" = "MG",
  "32" = "ES",
  "33" = "RJ",
  "35" = "SP",
  "41" = "PR",
  "42" = "SC",
  "43" = "RS",
  "50" = "MS",
  "51" = "MT",
  "52" = "GO",
  "53" = "DF"
)

# Build the snapshot ----

#' Build the `siconfi_taxes` release snapshot
#'
#' @param finbra_dir Directory holding the FINBRA ZIPs (each containing a
#'   `finbra.csv`); defaults to `getOption("realestatebr.finbra_dir")` or
#'   `data-raw/siconfi/finbra`. Never committed.
#' @param api_years Exercise years to re-fetch from the SICONFI `/dca`
#'   API; rows of those municipality-years replace the FINBRA rows and get
#'   `source = "api"`. Defaults to the two latest FINBRA years. Pass
#'   `integer()` (empty) to build from the FINBRA files alone, with no API
#'   traffic.
#' @param output_dir Write directory for `siconfi_taxes.rds` and
#'   `siconfi_taxes_manifest.json` (gitignored).
#' @param checkpoint_dir Directory for the per-municipality-year API
#'   checkpoints and the cached `/entes` universe (gitignored). Checkpoints
#'   make the hours-long API refresh resumable; delete them to re-request.
#'
#' @return The path of the written RDS, invisibly.
build_siconfi_snapshot <- function(
  finbra_dir = siconfi_finbra_dir(),
  api_years = NULL,
  output_dir = file.path("data-raw", "siconfi", "output"),
  checkpoint_dir = file.path("data-raw", "siconfi", "checkpoints")
) {
  if (!dir.exists(finbra_dir)) {
    cli::cli_abort(
      "FINBRA directory {.path {finbra_dir}} not found. Download the bulk \\
       ZIPs there or pass {.arg finbra_dir}."
    )
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)

  finbra <- siconfi_harvest_finbra(finbra_dir)
  if (is.null(api_years)) {
    api_years <- utils::tail(sort(unique(finbra$long$year)), 2L)
    cli::cli_inform(
      "{.arg api_years} not given: refreshing the two latest FINBRA \\
       years {.val {api_years}}."
    )
  }
  api_long <- siconfi_harvest_api(api_years, checkpoint_dir)
  universe <- siconfi_entes_universe(checkpoint_dir)

  siconfi_check_abbreviations(finbra$long)

  data <- siconfi_internal()$build_siconfi_taxes(
    finbra = finbra$long,
    api = if (nrow(api_long) == 0L) NULL else api_long,
    municipalities = universe
  )
  siconfi_internal()$validate_siconfi_taxes(data)

  coverage <- as.data.frame(siconfi_coverage(data))
  siconfi_coverage_gate(coverage, as.integer(api_years))

  rds_path <- file.path(output_dir, "siconfi_taxes.rds")
  siconfi_write_rds(data, rds_path)
  cli::cli_inform(
    "Built {.val siconfi_taxes}: {.val {nrow(data)}} rows, exercise years \\
     {.val {min(data$year)}} to {.val {max(data$year)}}, written to \\
     {.path {rds_path}}."
  )

  manifest <- list(
    dataset = "siconfi_taxes",
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    finbra = list(directory = unname(finbra_dir), files = finbra$files),
    api_refresh = list(
      years = as.integer(api_years),
      checkpoint_dir = unname(checkpoint_dir),
      completed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    ),
    coverage = coverage,
    release = list(
      file = "siconfi_taxes.rds",
      sha256 = digest::digest(rds_path, algo = "sha256", file = TRUE),
      bytes = unname(file.size(rds_path))
    )
  )
  manifest_path <- file.path(output_dir, "siconfi_taxes_manifest.json")
  siconfi_write_text(
    jsonlite::toJSON(
      manifest,
      pretty = TRUE,
      auto_unbox = TRUE,
      na = "null"
    ),
    manifest_path
  )
  cli::cli_inform("Coverage manifest written to {.path {manifest_path}}.")

  return(invisible(rds_path))
}

# Package internals ----

#' Namespaced access to the internal siconfi machinery
#'
#' Loads the package with `devtools::load_all()` on first use and returns
#' its namespace so the maintainer script reaches the internal functions.
siconfi_internal <- local({
  namespace <- NULL
  function() {
    if (is.null(namespace)) {
      check_siconfi_dependencies(c("devtools", "digest", "jsonlite"))
      if (!"realestatebr" %in% loadedNamespaces()) {
        devtools::load_all()
      }
      found <- asNamespace("realestatebr")
      missing <- setdiff(SICONFI_INTERNALS, ls(found, all.names = TRUE))
      if (length(missing) > 0L) {
        cli::cli_abort(
          "Internal helper{?s} {.val {missing}} not found in the package."
        )
      }
      namespace <<- found
    }
    return(namespace)
  }
})

check_siconfi_dependencies <- function(packages) {
  present <- vapply(
    packages,
    function(package) requireNamespace(package, quietly = TRUE),
    logical(1L)
  )
  missing <- names(present[!present])
  if (length(missing) > 0L) {
    cli::cli_abort("Install build dependencies: {.pkg {missing}}.")
  }
  return(invisible(TRUE))
}

#' The FINBRA bulk-file directory
#'
#' Defaults: the `finbra_dir` argument, then
#' `getOption("realestatebr.finbra_dir")`, then `data-raw/siconfi/finbra`.
siconfi_finbra_dir <- function() {
  return(
    getOption(
      "realestatebr.finbra_dir",
      file.path("data-raw", "siconfi", "finbra")
    )
  )
}

# FINBRA harvest ----

siconfi_harvest_finbra <- function(finbra_dir) {
  paths <- list.files(
    finbra_dir,
    pattern = "\\.(zip|csv)$",
    ignore.case = TRUE,
    full.names = TRUE
  )
  if (length(paths) == 0L) {
    cli::cli_abort(
      "No FINBRA ZIPs in {.path {finbra_dir}}; download the Receitas \\
       Orçamentárias (Anexo I-C) files from Tesouro."
    )
  }

  cli::cli_inform(
    "Reading {length(paths)} FINBRA files from {.path {finbra_dir}}."
  )
  parsed <- list()
  files <- list()
  reporter_keys <- character()
  file_years <- integer()
  for (i in seq_along(paths)) {
    path <- paths[[i]]
    long <- siconfi_internal()$read_finbra_file(path)
    years <- unique(long$year)
    if (length(years) != 1L) {
      cli::cli_abort(
        "FINBRA file {.path {path}} covers years {.val {years}}; every \\
         file holds exactly one exercise."
      )
    }
    file_years <- c(file_years, years)
    reporter_keys <- c(reporter_keys, attr(long, "reporters"))
    parsed[[i]] <- long
    files[[i]] <- list(
      file = basename(path),
      exercise = as.integer(years),
      rows = nrow(long),
      # Distinct reporters by any account line, matching the plan's
      # per-year municipality counts.
      municipalities = length(unique(
        sub(" [0-9]{4}$", "", attr(long, "reporters"))
      )),
      sha256 = digest::digest(path, algo = "sha256", file = TRUE),
      bytes = unname(file.size(path))
    )
    cli::cli_inform(
      "{.path {basename(path)}}: exercise {.val {years}}, \\
       {.val {nrow(long)}} tax rows, {.val {files[[i]]$municipalities}} \\
       municipalities."
    )
  }

  duplicated_years <- unique(file_years[duplicated(file_years)])
  if (length(duplicated_years) > 0L) {
    offending <- basename(paths[file_years %in% duplicated_years])
    cli::cli_abort(
      c(
        "Multiple FINBRA files cover year{?s} {.val {duplicated_years}}.",
        "x" = "Files: {.path {offending}}."
      )
    )
  }

  years <- sort(unique(unlist(lapply(parsed, `[[`, "year"))))
  gaps <- setdiff(seq(min(years), max(years)), years)
  if (length(gaps) > 0L) {
    cli::cli_abort(
      "FINBRA files skip exercise years {.val {gaps}} between \\
       {.val {min(years)}} and {.val {max(years)}}; the gap breaks the \\
       non-reporter fill."
    )
  }

  long <- dplyr::bind_rows(parsed)
  attr(long, "reporters") <- unique(reporter_keys)
  return(list(long = long, files = unname(files)))
}

# SICONFI API harvest ----

siconfi_harvest_api <- function(api_years, checkpoint_dir) {
  if (length(api_years) == 0L) {
    cli::cli_inform("API refresh disabled (empty {.arg api_years}).")
    return(empty_long_form())
  }

  universe <- siconfi_entes_universe(checkpoint_dir)
  munis <- sprintf("%.0f", universe$code_muni)
  total <- length(munis) * length(api_years)
  cli::cli_inform(
    "Refreshing exercise years {.val {api_years}} for {.val {length(munis)}} \\
     municipalities ({.val {total}} municipality-years, at most one \\
     request per second; checkpoints in {.path {checkpoint_dir}})."
  )

  parsed <- list()
  reporters <- character()
  done <- 0L
  for (year in api_years) {
    for (code in munis) {
      checkpoint <- file.path(
        checkpoint_dir,
        sprintf("dca_%s_%d.rds", code, year)
      )
      if (file.exists(checkpoint)) {
        checkpointed <- readRDS(checkpoint)
        if (is.data.frame(checkpointed)) {
          # Earlier checkpoints stored the parsed long form only; keep
          # serving them and fall back to the tax rows of the year.
          long <- checkpointed
          key_reporters <- unique(paste(long$code_muni, long$year))
        } else {
          long <- checkpointed$long
          key_reporters <- checkpointed$reporters
        }
      } else {
        items <- siconfi_internal()$fetch_siconfi_dca(code, year)
        long <- siconfi_internal()$parse_siconfi_dca(items)
        key_reporters <- if (length(items) > 0L) {
          paste(code, year)
        } else {
          character()
        }
        siconfi_write_rds(
          list(
            long = long,
            reporters = key_reporters,
            raw_items = length(items)
          ),
          checkpoint
        )
      }
      attr(long, "reporters") <- key_reporters
      parsed[[length(parsed) + 1L]] <- long
      reporters <- c(reporters, key_reporters)

      done <- done + 1L
      if (done %% 50L == 0L) {
        cli::cli_inform(
          "{.val {done}}/{.val {total}} municipality-years done."
        )
      }
    }
  }

  long <- dplyr::bind_rows(parsed)
  attr(long, "reporters") <- unique(reporters)
  return(long)
}

empty_long_form <- function() {
  return(tibble::tibble(
    year = integer(),
    code_muni = character(),
    abbrev_state = character(),
    institution = character(),
    tax = character(),
    value_kind = character(),
    value = double()
  ))
}

# Municipality universe ----

#' Municipality universe from SICONFI `/entes`
#'
#' Keeps only `esfera = "M"` entries and caches the result. The register
#' (`cod_ibge`, `ente`, `regiao`, `uf`, `esfera`, verified live on 23 Oct
#' 2026) is the current register, not proof that a municipality existed or
#' reported in every historical year; the coverage manifest records the
#' resulting per-year counts as the sanity gate (plan risk).
siconfi_entes_universe <- function(checkpoint_dir) {
  cached <- file.path(checkpoint_dir, "universe_entes.rds")
  if (file.exists(cached)) {
    return(readRDS(cached))
  }

  cli::cli_inform(
    "Fetching the municipality register from {.url {SICONFI_ENTES_URL}}."
  )
  response <- siconfi_internal()$download_with_retry(
    fn = function() {
      result <- httr::GET(SICONFI_ENTES_URL)
      httr::stop_for_status(result)
      return(jsonlite::fromJSON(
        httr::content(result, as = "text", encoding = "UTF-8"),
        simplifyVector = FALSE
      ))
    },
    max_retries = 3,
    quiet = FALSE,
    desc = "SICONFI /entes request"
  )

  items <- response$items %||% list()
  if (isTRUE(response$hasMore)) {
    cli::cli_abort(
      "The /entes register paginated beyond the first \\
       {.val {length(items)}} items; raise the request limit."
    )
  }
  municipality <- items[vapply(
    items,
    function(item) {
      identical(item$esfera, "M")
    },
    logical(1L)
  )]
  if (length(municipality) == 0L) {
    cli::cli_abort("No municipality (esfera = M) entries in /entes.")
  }

  codes <- vapply(
    municipality,
    function(item) {
      code <- sprintf("%.0f", as.numeric(item$cod_ibge))
      if (!grepl("^[0-9]{7}$", code)) {
        cli::cli_abort("Malformed /entes cod_ibge {.val {item$cod_ibge}}.")
      }
      return(code)
    },
    character(1L)
  )

  # `uf` carries the two-letter abbreviation in the current register; the
  # IBGE state-code prefix map is the offline fallback.
  states <- vapply(
    seq_along(municipality),
    function(i) {
      abbrev <- trimws(municipality[[i]]$uf %||% "")
      if (!abbrev %in% SICONFI_STATE_CODES) {
        return(unname(SICONFI_STATE_CODES[substr(codes[[i]], 1L, 2L)]))
      }
      return(abbrev)
    },
    character(1L)
  )

  universe <- dplyr::distinct(
    tibble::tibble(
      code_muni = as.integer(codes),
      abbrev_state = unname(states)
    )
  )
  cli::cli_inform(
    "Municipality universe: {.val {nrow(universe)}} cities \\
     (esfera = M, {.val {length(unique(universe$abbrev_state))}} states)."
  )

  siconfi_write_rds(universe, cached)
  return(universe)
}

siconfi_check_abbreviations <- function(finbra) {
  observed <- setdiff(unique(finbra$abbrev_state), c(NA_character_, ""))
  bad <- setdiff(observed, SICONFI_STATE_CODES)
  if (length(bad) > 0L) {
    cli::cli_abort(
      "Unexpected state abbreviation{?s} in FINBRA rows: \\
       {.val {head(bad)}}; check the parsing and the state map."
    )
  }
  return(invisible(TRUE))
}

# Coverage ----

siconfi_coverage <- function(data) {
  coverage <- dplyr::group_by(data, .data$year) |>
    dplyr::summarise(
      rows = dplyr::n(),
      municipalities = dplyr::n_distinct(.data$code_muni),
      reported_municipalities = dplyr::n_distinct(
        .data$code_muni[.data$reported]
      ),
      api_municipalities = dplyr::n_distinct(
        .data$code_muni[!is.na(.data$source) & .data$source == "api"]
      ),
      finbra_municipalities = dplyr::n_distinct(
        .data$code_muni[!is.na(.data$source) & .data$source == "finbra"]
      ),
      .groups = "drop"
    )
  coverage <- dplyr::mutate(
    coverage,
    expected_municipalities = unname(
      SICONFI_PLAN_MUNIS[as.character(.data$year)]
    ),
    plan_deviation = round(
      .data$reported_municipalities / .data$expected_municipalities - 1,
      3
    )
  )
  return(as.data.frame(coverage))
}

#' Coverage sanity gate
#'
#' Warns (never silently publishes) when a non-refreshed year deviates
#' more than 6% from the plan's per-year municipality counts. Refreshed
#' API years are exempt: the current `/entes` register legitimately
#' re-covers them, including past gaps and new municipalities.
siconfi_coverage_gate <- function(coverage, api_years) {
  missing_anchor <- coverage$year[is.na(coverage$expected_municipalities)]
  if (length(missing_anchor) > 0L) {
    cli::cli_warn(
      "{.val SICONFI_PLAN_MUNIS} has no per-year anchor for year{?s} \\
       {.val {missing_anchor}}; coverage is unverified."
    )
  }

  compared <- coverage[
    !is.na(coverage$plan_deviation) &
      !(coverage$year %in% api_years),
  ]
  deviating <- compared$year[abs(compared$plan_deviation) > 0.06]
  if (length(deviating) > 0L) {
    cli::cli_warn(
      "Reported municipality counts deviate more than 6% from the plan \\
       table for year{?s} {.val {deviating}} (the plan's 2014 caveat); \\
       check Tesouro delivery notes before publishing."
    )
  }
  return(invisible(TRUE))
}

# Atomic writes ----

siconfi_write_rds <- function(data, path) {
  temp_path <- paste0(path, ".tmp")
  saveRDS(data, temp_path)
  if (!file.rename(temp_path, path)) {
    cli::cli_abort(
      "Could not move the staged file into place: {.path {path}}."
    )
  }
  return(invisible(path))
}

siconfi_write_text <- function(text, path) {
  temp_path <- paste0(path, ".tmp")
  writeLines(text, temp_path, useBytes = TRUE)
  if (!file.rename(temp_path, path)) {
    cli::cli_abort(
      "Could not move the staged file into place: {.path {path}}."
    )
  }
  return(invisible(path))
}
