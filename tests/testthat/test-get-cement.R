# Assumed internal interfaces for implementation:
# resolve_snic_pdf_url(index_html, label, index_url)
# parse_cement_pdf(text)
# read_cement_archive(path, concept, years)
# compare_cement_overlap(archive, pdf)
# splice_cement_sources(archive, pdf)
# validate_cement_data(data)
# download_cement_pdf(url, destfile, download)
# Parsers return the eight-column long schema in the dataset plan.

local_edition(3)

cement_text_fixture <- function(name) {
  path <- testthat::test_path("fixtures", "cement", name)
  bytes <- readBin(path, what = "raw", n = file.info(path)$size)
  return(rawToChar(bytes))
}

cement_broken_text <- function(name) {
  path <- testthat::test_path("fixtures", "cement", "broken_variants.yaml")
  variant <- yaml::read_yaml(path)[[name]]
  text <- cement_text_fixture("consumption_2025.txt")

  if (variant$action == "replace") {
    return(sub(variant$pattern, variant$replacement, text, fixed = TRUE))
  }

  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  row <- grep(variant$pattern, lines)[[1]]
  if (variant$action == "remove_line") {
    lines <- lines[-row]
  } else if (variant$action == "duplicate_line") {
    lines <- append(lines, lines[[row]], after = row)
  }
  return(paste(lines, collapse = "\n"))
}

cement_archive_fixture <- function(concept) {
  return(testthat::test_path(
    "fixtures",
    "cement",
    paste0("archive_", concept, "_excerpt.xlsx")
  ))
}

cement_cell <- function(
  dat,
  date,
  geography_type,
  code_region = NA_integer_,
  code_state = NA_integer_
) {
  keep <- dat$date == as.Date(date) & dat$geography_type == geography_type
  if (is.na(code_region)) {
    keep <- keep & is.na(dat$code_region)
  } else {
    keep <- keep & dat$code_region == code_region
  }
  if (is.na(code_state)) {
    keep <- keep & is.na(dat$code_state)
  } else {
    keep <- keep & dat$code_state == code_state
  }
  result <- dat[which(keep), , drop = FALSE]
  expect_equal(nrow(result), 1L)
  return(result)
}

test_that("SNIC index resolves one exact producer link", {
  html <- cement_text_fixture("index_excerpt.html")
  base <- "https://snic.org.br/numeros-da-industria.php"

  expect_identical(
    resolve_snic_pdf_url(html, "Consumo Regional 2025", base),
    "https://snic.org.br/assets/pdf/numeros/1784570419.pdf"
  )
  expect_identical(
    resolve_snic_pdf_url(html, "Produção Regional 2025", base),
    "https://snic.org.br/assets/pdf/numeros/1784570386.pdf"
  )

  expect_error(
    resolve_snic_pdf_url(html, "Consumo Regional 2026", base),
    "label|missing|not found",
    class = "rlang_error"
  )

  duplicate <- sub(
    "</body>",
    '<a href="./assets/pdf/numeros/other.pdf">Consumo Regional 2025</a></body>',
    html,
    fixed = TRUE
  )
  expect_error(
    resolve_snic_pdf_url(duplicate, "Consumo Regional 2025", base),
    "duplicate|multiple|one",
    class = "rlang_error"
  )

  external <- sub(
    "./assets/pdf/numeros/1784570419.pdf",
    "https://example.org/1784570419.pdf",
    html,
    fixed = TRUE
  )
  expect_error(
    resolve_snic_pdf_url(external, "Consumo Regional 2025", base),
    "SNIC|host|domain|URL",
    class = "rlang_error"
  )
})

test_that("2025 PDF parsers preserve complete geography and monthly schema", {
  for (concept in c("consumption", "production")) {
    dat <- parse_cement_pdf(cement_text_fixture(paste0(concept, "_2025.txt")))

    expect_s3_class(dat, "tbl_df")
    expect_named(
      dat,
      c(
        "date",
        "geography_type",
        "code_region",
        "abbrev_state",
        "code_state",
        "value",
        "unit",
        "source_kind"
      )
    )
    expect_s3_class(dat$date, "Date")
    expect_type(dat$geography_type, "character")
    expect_type(dat$code_region, "integer")
    expect_type(dat$abbrev_state, "character")
    expect_type(dat$code_state, "integer")
    expect_type(dat$value, "double")
    expect_type(dat$unit, "character")
    expect_type(dat$source_kind, "character")
    expect_equal(
      sort(unique(dat$date)),
      seq(as.Date("2025-01-01"), as.Date("2025-12-01"), by = "month")
    )
    expect_equal(
      as.integer(table(dat$geography_type)[c(
        "state",
        "adjustment",
        "region",
        "brazil"
      )]),
      c(324L, 48L, 60L, 12L)
    )
    expect_equal(
      length(unique(dat$code_state[dat$geography_type == "state"])),
      27L
    )
    expect_identical(unique(dat$unit), "tonnes")
    expect_identical(unique(dat$source_kind), "snic_pdf")
    expect_no_error(validate_cement_data(dat))
  }
})

test_that("PDF identity matches the requested concept and year", {
  consumption <- cement_text_fixture("consumption_2025.txt")
  production <- cement_text_fixture("production_2025.txt")
  expect_no_error(parse_cement_pdf(
    consumption,
    concept = "consumption",
    year = 2025L
  ))
  expect_error(
    parse_cement_pdf(production, concept = "consumption", year = 2025L),
    "concept|title|consumption",
    class = "rlang_error"
  )
  expect_error(
    parse_cement_pdf(consumption, concept = "consumption", year = 2026L),
    "year|2026",
    class = "rlang_error"
  )
})

test_that("PDF coverage rejects a lost historical month in a new snapshot", {
  pdf <- dplyr::bind_rows(
    parse_cement_pdf(cement_text_fixture("consumption_2024.txt")),
    parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  )
  pdf$value[pdf$date == as.Date("2024-12-01")] <- NA_real_
  expect_error(
    validate_cement_pdf_coverage(pdf),
    "month|coverage|December|2024",
    class = "rlang_error"
  )
})

test_that("overlap flags missing values and published cells cannot disappear", {
  archive <- read_cement_archive(
    cement_archive_fixture("consumption"),
    concept = "consumption",
    years = 2024L
  )
  pdf <- parse_cement_pdf(cement_text_fixture("consumption_2024.txt"))
  pdf$value[pdf$date == as.Date("2024-12-01")] <- NA_real_
  expect_equal(nrow(compare_cement_overlap(archive, pdf)), 37L)
  expect_error(
    validate_cement_observed_values(archive, pdf, "consumption"),
    "lost|missing|published",
    class = "rlang_error"
  )
})

test_that("missing aggregate totals cannot hide observed components", {
  dat <- parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  brazil_missing <- dat
  brazil_missing$value[
    brazil_missing$date == as.Date("2025-01-01") &
      brazil_missing$geography_type == "brazil"
  ] <- NA_real_
  expect_error(
    validate_cement_data(brazil_missing),
    "Brazil|total|missing",
    class = "rlang_error"
  )

  region_missing <- dat
  region_missing$value[
    region_missing$date == as.Date("2025-01-01") &
      region_missing$geography_type == "region" &
      region_missing$code_region == 1L
  ] <- NA_real_
  expect_error(
    validate_cement_data(region_missing),
    "region|total|missing",
    class = "rlang_error"
  )
})

test_that("wholly missing historical months cannot pass validation", {
  dat <- dplyr::bind_rows(
    parse_cement_pdf(cement_text_fixture("consumption_2024.txt")),
    parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  )
  dat$value[dat$date == as.Date("2024-12-01")] <- NA_real_
  expect_error(
    validate_cement_data(dat),
    "historical month|missing|coverage",
    class = "rlang_error"
  )

  future <- parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  future$value[future$date == as.Date("2025-12-01")] <- NA_real_
  expect_no_error(validate_cement_data(future))
})

test_that("failed second-table refresh leaves every existing output unchanged", {
  destination <- tempfile("cement-snapshot-")
  dir.create(destination)
  on.exit(unlink(destination, recursive = TRUE), add = TRUE)
  old <- list(
    consumption = parse_cement_pdf(cement_text_fixture("consumption_2025.txt")),
    production = parse_cement_pdf(cement_text_fixture("production_2025.txt"))
  )
  new <- old
  new$consumption$source_kind <- "refreshed"
  new$production$value[
    new$production$date == as.Date("2025-01-01") &
      new$production$geography_type == "brazil"
  ] <- NA_real_
  for (concept in names(old)) {
    saveRDS(
      old[[concept]],
      file.path(destination, paste0("cement_", concept, ".rds"))
    )
  }
  readr::write_csv(
    data.frame(source = "old"),
    file.path(destination, "cement_sources.csv")
  )
  readr::write_csv(
    data.frame(change = "old"),
    file.path(destination, "cement_overlap_diff.csv")
  )
  before <- tools::md5sum(list.files(destination, full.names = TRUE))
  expect_error(
    publish_cement_snapshots(
      new,
      destination,
      data.frame(source = "new"),
      data.frame(change = "new")
    ),
    "production.*lost|production.*missing|production.*published",
    class = "rlang_error"
  )
  expect_identical(tools::md5sum(names(before)), before)
})

test_that("rename warnings roll back every existing snapshot with warn = 2", {
  destination <- tempfile("cement-rename-")
  dir.create(destination)
  on.exit(unlink(destination, recursive = TRUE), add = TRUE)

  old <- list(
    consumption = parse_cement_pdf(cement_text_fixture("consumption_2025.txt")),
    production = parse_cement_pdf(cement_text_fixture("production_2025.txt"))
  )
  for (concept in names(old)) {
    saveRDS(
      old[[concept]],
      file.path(destination, paste0("cement_", concept, ".rds"))
    )
  }
  readr::write_csv(
    data.frame(source = "old"),
    file.path(destination, "cement_sources.csv")
  )
  readr::write_csv(
    data.frame(change = "old"),
    file.path(destination, "cement_overlap_diff.csv")
  )
  paths <- list.files(destination, full.names = TRUE)
  before <- lapply(paths, function(path) {
    readBin(path, what = "raw", n = file.info(path)$size)
  })

  refreshed <- old
  refreshed$consumption$source_kind <- "refreshed"
  refreshed$production$source_kind <- "refreshed"
  rename <- base::file.rename
  rename_calls <- 0L
  local_mocked_bindings(
    file.rename = function(from, to) {
      rename_calls <<- rename_calls + 1L
      if (rename_calls == 2L) {
        warning("simulated rename failure")
        return(FALSE)
      }
      return(rename(from, to))
    },
    .package = "base"
  )
  withr::local_options(warn = 2)

  expect_error(
    publish_cement_snapshots(
      refreshed,
      destination,
      data.frame(source = "new"),
      data.frame(change = "new")
    ),
    "Could not replace",
    class = "rlang_error"
  )
  expect_identical(rename_calls, 2L)
  for (i in seq_along(paths)) {
    expect_identical(
      readBin(paths[[i]], what = "raw", n = file.info(paths[[i]])$size),
      before[[i]]
    )
  }
  expect_identical(sort(list.files(destination)), sort(basename(paths)))
})

test_that("incomplete snapshot rollback keeps backups and names them", {
  destination <- tempfile("cement-rollback-")
  dir.create(destination)
  on.exit(unlink(destination, recursive = TRUE), add = TRUE)

  old <- list(
    consumption = parse_cement_pdf(cement_text_fixture("consumption_2025.txt")),
    production = parse_cement_pdf(cement_text_fixture("production_2025.txt"))
  )
  for (concept in names(old)) {
    saveRDS(
      old[[concept]],
      file.path(destination, paste0("cement_", concept, ".rds"))
    )
  }
  original_hashes <- tools::md5sum(list.files(destination, full.names = TRUE))
  refreshed <- old
  refreshed$consumption$source_kind <- "refreshed"
  refreshed$production$source_kind <- "refreshed"
  rename <- base::file.rename
  copy <- base::file.copy
  rename_calls <- 0L
  local_mocked_bindings(
    file.rename = function(from, to) {
      rename_calls <<- rename_calls + 1L
      if (rename_calls == 2L) {
        warning("simulated rename failure")
        return(FALSE)
      }
      return(rename(from, to))
    },
    file.copy = function(from, to, overwrite = FALSE, ...) {
      if (overwrite) {
        return(FALSE)
      }
      return(copy(from, to, overwrite = overwrite, ...))
    },
    .package = "base"
  )
  withr::local_options(warn = 2)

  failure <- tryCatch(
    publish_cement_snapshots(
      refreshed,
      destination,
      data.frame(source = "new"),
      data.frame(change = "new")
    ),
    error = identity
  )
  expect_s3_class(failure, "rlang_error")
  backups <- list.files(destination, pattern = "\\.bak$", full.names = TRUE)
  expect_length(backups, 2L)
  for (path in backups) {
    expect_true(grepl(path, conditionMessage(failure), fixed = TRUE))
  }
  expect_identical(
    sort(unname(tools::md5sum(backups))),
    sort(unname(original_hashes))
  )
})

test_that("snapshot hashes accept paths containing spaces", {
  skip_on_os("windows")
  path <- tempfile("cement hash ")
  writeBin(charToRaw("cement"), path)
  on.exit(unlink(path), add = TRUE)
  expect_match(cement_sha256(path), "^[a-f0-9]{64}$")
})

test_that("cement help renders the complete comparability warning", {
  help_file <- testthat::test_path("..", "..", "man", "cement.Rd")
  topic <- if (file.exists(help_file)) {
    help_file
  } else {
    utils:::.getHelpFile(utils::help("cement", package = "realestatebr"))
  }
  rendered <- paste(capture.output(tools::Rd2txt(topic)), collapse = "\n")
  expect_match(rendered, "5% to about 13% of Brazil consumption", fixed = TRUE)
})

test_that("PDF numbers, adjustment placement, and dashes retain source meaning", {
  consumption <- parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  production <- parse_cement_pdf(cement_text_fixture("production_2025.txt"))

  expect_equal(
    cement_cell(consumption, "2025-01-01", "state", 3L, 35L)$value,
    1158600
  )
  expect_equal(
    cement_cell(consumption, "2025-01-01", "adjustment", 1L)$value,
    18000
  )
  expect_equal(
    cement_cell(consumption, "2025-01-01", "region", 1L)$value,
    309030
  )
  expect_equal(cement_cell(consumption, "2025-01-01", "brazil")$value, 5216773)
  expect_equal(
    cement_cell(production, "2025-01-01", "state", 2L, 23L)$value,
    264206
  )
  expect_true(is.na(
    cement_cell(production, "2025-01-01", "state", 1L, 12L)$value
  ))
  expect_equal(
    sum(is.na(production$value[production$geography_type == "state"])),
    48L
  )
  expect_no_error(validate_cement_data(consumption))
  expect_no_error(validate_cement_data(production))
})

test_that("archive parser keeps fractional tonnes, units, and missing markers", {
  dat <- read_cement_archive(
    cement_archive_fixture("consumption"),
    concept = "consumption",
    years = c(2004L, 2014L, 2015L, 2016L, 2023L, 2024L)
  )

  expect_s3_class(dat, "tbl_df")
  expect_named(
    dat,
    c(
      "date",
      "geography_type",
      "code_region",
      "abbrev_state",
      "code_state",
      "value",
      "unit",
      "source_kind"
    )
  )
  expect_s3_class(dat$date, "Date")
  expect_type(dat$code_region, "integer")
  expect_type(dat$code_state, "integer")
  expect_type(dat$value, "double")
  expect_identical(unique(dat$unit), "tonnes")
  expect_identical(unique(dat$source_kind), "archive")
  expect_equal(cement_cell(dat, "2004-01-01", "state", 1L, 14L)$value, 5752.5)
  expect_equal(
    cement_cell(dat, "2004-01-01", "state", 3L, 35L)$value,
    706730.927,
    tolerance = 1e-6
  )
  expect_true(is.na(cement_cell(dat, "2014-03-01", "state", 1L, 11L)$value))
  expect_true(is.na(cement_cell(dat, "2016-12-01", "state", 3L, 35L)$value))
  expect_equal(cement_cell(dat, "2014-03-01", "region", 1L)$value, 386190)
  expect_equal(cement_cell(dat, "2014-03-01", "brazil")$value, 5719000)
  expect_false(any(dat$value == 0, na.rm = TRUE))
})

test_that("the monthly state gap is explicit while all regional totals remain", {
  dat <- read_cement_archive(
    cement_archive_fixture("consumption"),
    concept = "consumption",
    years = c(2014L, 2015L, 2016L)
  )
  gap_months <- seq(as.Date("2014-03-01"), as.Date("2016-12-01"), by = "month")
  states <- dat[dat$geography_type == "state" & dat$date %in% gap_months, ]
  regions <- dat[dat$geography_type == "region" & dat$date %in% gap_months, ]
  brazil <- dat[dat$geography_type == "brazil" & dat$date %in% gap_months, ]

  expect_equal(nrow(states), 34L * 27L)
  expect_true(all(is.na(states$value)))
  expect_equal(nrow(regions), 34L * 5L)
  expect_true(all(!is.na(regions$value)))
  expect_equal(nrow(brazil), 34L)
  expect_true(all(!is.na(brazil$value)))
  expect_no_error(validate_cement_data(dat))
})

test_that("all 2024 archive months equal the PDF vintage", {
  for (concept in c("consumption", "production")) {
    archive <- read_cement_archive(
      cement_archive_fixture(concept),
      concept = concept,
      years = 2024L
    )
    pdf <- parse_cement_pdf(cement_text_fixture(paste0(concept, "_2024.txt")))

    expect_equal(nrow(compare_cement_overlap(archive, pdf)), 0L)
    expect_equal(nrow(archive), nrow(pdf))
    expect_no_error(validate_cement_data(pdf))
  }
})

test_that("January 2025 production revisions are not masked by the archive", {
  archive <- read_cement_archive(
    cement_archive_fixture("production"),
    concept = "production",
    years = 2025L
  )
  pdf <- parse_cement_pdf(cement_text_fixture("production_2025.txt"))
  changes <- compare_cement_overlap(archive, pdf)

  observed_changes <- changes[
    !is.na(changes$archive_value) & !is.na(changes$pdf_value),
  ]
  expect_equal(nrow(observed_changes), 5L)
  expect_equal(nrow(changes), 368L)
  expect_equal(
    cement_cell(archive, "2025-01-01", "state", 2L, 23L)$value,
    272197
  )
  expect_equal(cement_cell(pdf, "2025-01-01", "state", 2L, 23L)$value, 264206)
  expect_equal(
    cement_cell(archive, "2025-01-01", "state", 2L, 28L)$value,
    178283
  )
  expect_equal(cement_cell(pdf, "2025-01-01", "state", 2L, 28L)$value, 175813)
  expect_equal(
    cement_cell(archive, "2025-01-01", "state", 2L, 29L)$value,
    101452
  )
  expect_equal(cement_cell(pdf, "2025-01-01", "state", 2L, 29L)$value, 103922)
  expect_equal(cement_cell(archive, "2025-01-01", "region", 2L)$value, 1168618)
  expect_equal(cement_cell(pdf, "2025-01-01", "region", 2L)$value, 1160627)
  expect_equal(cement_cell(archive, "2025-01-01", "brazil")$value, 4944931)
  expect_equal(cement_cell(pdf, "2025-01-01", "brazil")$value, 4936940)
  future <- archive[archive$date >= as.Date("2025-02-01"), ]
  expect_false(any(future$value == 0, na.rm = TRUE))
  expect_true(all(is.na(future$value)))
})

test_that("the splice uses archive through 2023 and PDFs from 2024", {
  archive <- read_cement_archive(
    cement_archive_fixture("production"),
    concept = "production",
    years = c(2023L, 2024L, 2025L)
  )
  pdf <- rbind(
    parse_cement_pdf(cement_text_fixture("production_2024.txt")),
    parse_cement_pdf(cement_text_fixture("production_2025.txt"))
  )
  result <- splice_cement_sources(archive, pdf)

  expect_true(all(
    result$source_kind[result$date < as.Date("2024-01-01")] == "archive"
  ))
  expect_true(all(
    result$source_kind[result$date >= as.Date("2024-01-01")] == "snic_pdf"
  ))
  expect_equal(cement_cell(result, "2025-01-01", "brazil")$value, 4936940)
  expect_no_error(validate_cement_data(result))
})

test_that("validation rejects duplicate keys and both reconciliation failures", {
  dat <- parse_cement_pdf(cement_text_fixture("consumption_2025.txt"))
  duplicate <- rbind(dat, dat[1, ])
  expect_error(
    validate_cement_data(duplicate),
    "duplicate|unique|key",
    class = "rlang_error"
  )

  bad_region <- dat
  row <- which(
    bad_region$date == as.Date("2025-01-01") &
      bad_region$geography_type == "region" &
      bad_region$code_region == 1L
  )
  bad_region$value[row] <- bad_region$value[row] + 1
  expect_error(
    validate_cement_data(bad_region),
    "region|reconcil",
    class = "rlang_error"
  )

  bad_brazil <- dat
  row <- which(
    bad_brazil$date == as.Date("2025-01-01") &
      bad_brazil$geography_type == "brazil"
  )
  bad_brazil$value[row] <- bad_brazil$value[row] + 1
  expect_error(
    validate_cement_data(bad_brazil),
    "Brazil|reconcil",
    class = "rlang_error"
  )
})

test_that("each malformed PDF fixture aborts with a cli error", {
  cases <- c(
    broken_month_header = "month|header|Fex",
    broken_missing_state = "state|27",
    broken_duplicate_adjustment = "adjustment|Ajustes|duplicate",
    broken_malformed_number = "number|numeric|token",
    broken_total = "total|reconcil"
  )
  for (name in names(cases)) {
    expect_error(
      parse_cement_pdf(cement_broken_text(name)),
      cases[[name]],
      class = "rlang_error",
      info = name
    )
  }
})

test_that("cement registry declares both tables and their release assets", {
  registry <- load_dataset_registry()
  info <- registry$datasets$cement
  expect_true(!is.null(info))
  if (is.null(info)) {
    return(invisible(NULL))
  }

  expect_named(info$categories, c("consumption", "production"))
  expect_identical(info$default_table, "consumption")
  expect_identical(info$cached_file$consumption, "cement_consumption.rds")
  expect_identical(info$cached_file$production, "cement_production.rds")
  expect_identical(
    get_cached_name("cement", info, "production"),
    "cement_production"
  )
  expect_match(info$categories$consumption$description, "2014|2016|missing|gap")
})

test_that("cement resolves its default and production tables", {
  withr::defer(clear_session_cache())
  sample <- tibble::tibble(date = as.Date("2025-01-01"), value = 1)
  memo_set(memo_key("cement", "consumption"), sample)
  memo_set(memo_key("cement", "production"), sample)
  expect_identical(get_dataset("cement", quiet = TRUE), sample)
  expect_identical(
    get_dataset("cement", table = "production", quiet = TRUE),
    sample
  )
})

test_that("cement fresh mode aborts with a clear cli message", {
  expect_error(
    get_dataset("cement", source = "fresh", quiet = TRUE),
    "fresh|archive|unavailable",
    class = "rlang_error"
  )
})

test_that("cement GitHub dispatch chooses the two release assets", {
  withr::defer(clear_session_cache())
  clear_session_cache()
  names_seen <- character()
  local_mocked_bindings(
    fetch_github_release_asset = function(cached_name, quiet) {
      names_seen <<- c(names_seen, cached_name)
      tibble::tibble(date = as.Date("2025-01-01"), value = 1)
    }
  )

  get_dataset("cement", source = "github", quiet = TRUE)
  get_dataset("cement", table = "production", source = "github", quiet = TRUE)
  expect_identical(names_seen, c("cement_consumption", "cement_production"))
})

test_that("expired SNIC certificates stop PDF refresh with a cli error", {
  downloader <- function(...) {
    base::stop("SSL certificate problem: certificate has expired")
  }
  expect_error(
    download_cement_pdf(
      "https://snic.org.br/assets/pdf/numeros/1784570419.pdf",
      tempfile(fileext = ".pdf"),
      download = downloader
    ),
    "SNIC.*certificate.*expired|expired.*SNIC",
    class = "rlang_error"
  )
})

test_that("live SNIC index discovery remains opt in", {
  skip_on_cran()
  skip_if_not_live()
  url <- "https://snic.org.br/numeros-da-industria.php"
  response <- httr::GET(url)
  httr::stop_for_status(response)
  html <- httr::content(response, as = "text", encoding = "UTF-8")
  expect_match(
    resolve_snic_pdf_url(html, "Consumo Regional 2025", url),
    "^https://snic\\.org\\.br/assets/pdf/numeros/.*\\.pdf$"
  )
})
