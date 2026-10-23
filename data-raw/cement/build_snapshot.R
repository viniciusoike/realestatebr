# Build local SNIC cement snapshots ----

# Run after devtools::load_all(). The archive remains outside the package,
# and the output directory must be a local staging path, not inst/extdata.
build_cement_snapshot <- function(
  archive_dir = getOption("realestatebr.cement_archive_dir"),
  output_dir,
  pdf_dir = NULL,
  index_file = NULL,
  pdf_retrieved_date = Sys.Date()
) {
  if (is.null(archive_dir) || !dir.exists(archive_dir)) {
    cli::cli_abort(
      "Set {.arg archive_dir} or the {.code realestatebr.cement_archive_dir} option to the historical workbook directory."
    )
  }
  if (missing(output_dir) || !nzchar(output_dir)) {
    cli::cli_abort(
      "Provide a local {.arg output_dir} for the cement snapshots."
    )
  }
  if (!is.null(pdf_dir) && (is.null(index_file) || !dir.exists(pdf_dir))) {
    cli::cli_abort(
      "Local PDFs require an existing {.arg pdf_dir} and {.arg index_file}."
    )
  }
  if (!requireNamespace("pdftools", quietly = TRUE)) {
    cli::cli_abort("Install {.pkg pdftools} to parse the SNIC regional PDFs.")
  }

  sha256 <- function(path) {
    command <- if (nzchar(Sys.which("shasum"))) "shasum" else "sha256sum"
    args <- if (command == "shasum") c("-a", "256", path) else path
    result <- suppressWarnings(system2(
      command,
      args,
      stdout = TRUE,
      stderr = TRUE
    ))
    if (length(result) != 1L || !grepl("^[a-f0-9]{64} ", result)) {
      cli::cli_abort("Could not compute SHA-256 for {.file {path}}.")
    }
    return(substr(result, 1L, 64L))
  }

  index_url <- "https://snic.org.br/numeros-da-industria.php"
  if (is.null(index_file)) {
    response <- tryCatch(
      httr::GET(index_url),
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
            "SNIC TLS certificate has expired; refresh is blocked until SNIC renews it.",
            parent = cnd
          )
        }
        cli::cli_abort("SNIC index download failed: {reason}", parent = cnd)
      }
    )
    httr::stop_for_status(response)
    index_html <- httr::content(response, as = "text", encoding = "UTF-8")
  } else {
    index_html <- paste(
      readLines(index_file, encoding = "UTF-8", warn = FALSE),
      collapse = "\n"
    )
  }
  links <- rvest::html_elements(xml2::read_html(index_html), "a")
  labels <- trimws(rvest::html_text2(links))

  archive_specs <- list(
    consumption = list(
      pattern = "^tabela_07\\.A\\.03_.*_53\\.xlsx$",
      hash = "1204150b8e4c75a3e9c9a01b24f5bfde555383ecda456c199e970263387f6c9d",
      prefix = "consumo"
    ),
    production = list(
      pattern = "^tabela_07\\.A\\.04_.*_52\\.xlsx$",
      hash = "67057ddc8d9f54130d71289035f1110b8dc37753eebc9cd4af6eeccef8ed72d6",
      prefix = "produção"
    )
  )
  manifest <- list()
  differences <- list()
  snapshots <- list()

  for (concept in names(archive_specs)) {
    spec <- archive_specs[[concept]]
    archive_path <- list.files(
      archive_dir,
      pattern = spec$pattern,
      full.names = TRUE
    )
    if (length(archive_path) != 1L || sha256(archive_path) != spec$hash) {
      cli::cli_abort(
        "Cement {.val {concept}} archive file or SHA-256 differs from the approved source."
      )
    }
    archive <- read_cement_archive(archive_path, concept)
    label_prefix <- if (concept == "consumption") "Consumo" else "Produção"
    regional_labels <- labels[grepl(
      paste0("^", label_prefix, " Regional [0-9]{4}$"),
      labels
    )]
    years <- sort(as.integer(sub(".* ", "", regional_labels)))
    if (
      length(years) == 0L ||
        anyDuplicated(years) ||
        !identical(years, seq.int(2024L, max(years)))
    ) {
      cli::cli_abort(
        "SNIC index has missing or duplicate regional PDF years for {.val {concept}}."
      )
    }
    pdf_parts <- vector("list", length(years))
    for (i in seq_along(years)) {
      year <- years[[i]]
      label <- paste(label_prefix, "Regional", year)
      url <- resolve_snic_pdf_url(index_html, label, index_url)
      if (is.null(pdf_dir)) {
        pdf_path <- tempfile(fileext = ".pdf")
        download_cement_pdf(url, pdf_path)
      } else {
        pdf_path <- file.path(
          pdf_dir,
          sprintf("%s_regional_%d.pdf", spec$prefix, year)
        )
        if (!file.exists(pdf_path)) {
          cli::cli_abort("Missing local SNIC PDF {.file {pdf_path}}.")
        }
      }
      pages <- pdftools::pdf_text(pdf_path)
      if (length(pages) != 1L) {
        cli::cli_abort(
          "SNIC regional PDF {.file {pdf_path}} must have one page."
        )
      }
      pdf_parts[[i]] <- parse_cement_pdf(pages[[1]])
      manifest[[length(manifest) + 1L]] <- tibble::tibble(
        concept = concept,
        kind = "snic_pdf",
        year = year,
        source_url = url,
        retrieved_date = as.character(pdf_retrieved_date),
        sha256 = sha256(pdf_path)
      )
      if (is.null(pdf_dir)) unlink(pdf_path)
    }
    pdf <- dplyr::bind_rows(pdf_parts)
    diff <- compare_cement_overlap(archive, pdf)
    diff$concept <- concept
    differences[[concept]] <- diff
    snapshot <- splice_cement_sources(archive, pdf)
    observed <- pdf$date[pdf$geography_type == "brazil" & !is.na(pdf$value)]
    snapshot <- dplyr::filter(snapshot, .data$date <= max(observed))
    validate_cement_data(snapshot)
    snapshots[[concept]] <- snapshot
    manifest[[length(manifest) + 1L]] <- tibble::tibble(
      concept = concept,
      kind = "archive",
      year = NA_integer_,
      source_url = archive_path,
      retrieved_date = NA_character_,
      sha256 = spec$hash
    )
  }

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  for (concept in names(snapshots)) {
    destination <- file.path(output_dir, paste0("cement_", concept, ".rds"))
    if (file.exists(destination)) {
      old <- readRDS(destination)
      old_months <- old$date[old$geography_type == "brazil" & !is.na(old$value)]
      new <- snapshots[[concept]]
      new_months <- new$date[new$geography_type == "brazil" & !is.na(new$value)]
      if (!all(old_months %in% new_months)) {
        cli::cli_abort(
          "SNIC {.val {concept}} refresh lost an already-published month."
        )
      }
    }
    temporary <- tempfile(tmpdir = output_dir, fileext = ".rds")
    saveRDS(snapshots[[concept]], temporary, compress = "xz")
    if (!file.rename(temporary, destination)) {
      cli::cli_abort("Could not replace {.file {destination}}.")
    }
  }
  readr::write_csv(
    dplyr::bind_rows(manifest),
    file.path(output_dir, "cement_sources.csv")
  )
  readr::write_csv(
    dplyr::bind_rows(differences),
    file.path(output_dir, "cement_overlap_diff.csv")
  )
  return(invisible(snapshots))
}
