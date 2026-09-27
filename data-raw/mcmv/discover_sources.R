# Discover MCMV source files ----
#
# The Ministry publishes each release under new, irregular file names, such
# as `mcmv_subsidiado_202606302.zip`. Discovery therefore matches stable name
# prefixes on the landing page and reads the snapshot version from the data,
# never from the file name.

mcmv_landing_url <- paste0(
  "https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/",
  "habitacao/programa-minha-casa-minha-vida/",
  "bases-de-dados-do-programa-minha-casa-minha-vida"
)

mcmv_source_prefixes <- c(
  financing = "mcmv_financ_analitico_",
  financing_summary = "mcmv_financ_sintetico_",
  subsidized_projects = "mcmv_subsidiado_"
)

# Page links ----

discover_mcmv_sources <- function(html, base_url = mcmv_landing_url) {
  page <- xml2::read_html(paste(html, collapse = "\n"))
  hrefs <- xml2::xml_attr(xml2::xml_find_all(page, "//a[@href]"), "href")
  hrefs <- unique(xml2::url_absolute(trimws(hrefs), base_url))
  file_names <- basename(sub("[?#].*$", "", hrefs))

  urls <- vapply(
    names(mcmv_source_prefixes),
    function(table) {
      pattern <- paste0(
        "^",
        mcmv_source_prefixes[[table]],
        ".+[.](csv|zip|rar)$"
      )
      found <- hrefs[grepl(pattern, file_names, ignore.case = TRUE)]
      if (length(found) != 1L) {
        cli::cli_abort(c(
          "Expected one {.val {table}} file on the MCMV page, found {length(found)}.",
          "i" = "Links searched for the prefix {.val {mcmv_source_prefixes[[table]]}}.",
          stats::setNames(found, rep("*", length(found)))
        ))
      }
      return(found)
    },
    character(1)
  )
  return(urls)
}

# Change detection ----

mcmv_sources_changed <- function(urls, manifest) {
  if (is.null(manifest)) {
    return(TRUE)
  }
  published <- vapply(
    names(urls),
    function(table) {
      url <- manifest$source$files[[table]]$url
      if (is.null(url)) NA_character_ else url
    },
    character(1)
  )
  return(!identical(unname(published), unname(urls)))
}

read_mcmv_manifest <- function(latest_url) {
  latest <- tryCatch(
    jsonlite::read_json(latest_url),
    error = function(e) NULL,
    warning = function(w) NULL
  )
  if (is.null(latest)) {
    cli::cli_inform("No published MCMV snapshot found at {.url {latest_url}}.")
    return(NULL)
  }
  return(jsonlite::read_json(latest$manifest_url))
}

# Snapshot version ----

mcmv_reference_version <- function(path) {
  lines <- read_mcmv_head(path)
  header <- gsub('"', "", strsplit(lines[[1]], ";", fixed = TRUE)[[1]])
  values <- gsub('"', "", strsplit(lines[[2]], ";", fixed = TRUE)[[1]])
  column <- match("data_referencia", header)
  if (is.na(column)) {
    cli::cli_abort("{.path {path}} has no {.field data_referencia} column.")
  }
  reference <- as.Date(values[[column]], format = "%d/%m/%Y")
  if (is.na(reference) || !grepl("^\\d{2}/\\d{2}/\\d{4}$", values[[column]])) {
    cli::cli_abort(
      "Expected {.field data_referencia} as DD/MM/YYYY, found {.val {values[[column]]}}."
    )
  }
  return(format(reference, "%Y-%m-%d"))
}

read_mcmv_head <- function(path) {
  extension <- tolower(tools::file_ext(path))
  if (extension == "csv") {
    lines <- readLines(path, n = 2L, encoding = "UTF-8", warn = FALSE)
  } else if (extension %in% c("zip", "rar")) {
    if (!nzchar(Sys.which("bsdtar"))) {
      cli::cli_abort("Install bsdtar to read MCMV archives.")
    }
    con <- pipe(
      paste("bsdtar -xOf", shQuote(path), "2>/dev/null"),
      open = "r",
      encoding = "UTF-8"
    )
    on.exit(close(con), add = TRUE)
    lines <- readLines(con, n = 2L, warn = FALSE)
  } else {
    cli::cli_abort("Expected a CSV, ZIP, or RAR file, not {.path {path}}.")
  }
  if (length(lines) < 2L) {
    cli::cli_abort("{.path {path}} has no data rows.")
  }
  return(lines)
}
