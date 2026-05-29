#' GitHub Release Cache and In-Session Memo
#'
#' Fetches pre-processed datasets from the package's GitHub release assets
#' using a direct `httr::GET()` against the public release-asset URL. Avoids
#' the `piggyback` / `gh` dependency, which would otherwise write API
#' responses to `~/.cache/R/gh/` and violate CRAN policy on home-directory
#' writes.
#'
#' Also provides a package-private in-session memo so repeated calls within
#' one R session do not re-download the same asset.
#'
#' @name cache_github
#' @noRd
NULL

# Release configuration ------------------------------------------------------

# Public release-asset URL: GitHub serves these at a stable, unauthenticated
# URL — no API call required as long as the release is public.
GITHUB_CACHE_REPO <- "viniciusoike/realestatebr"
GITHUB_CACHE_TAG <- "cache-latest"

#' @noRd
github_release_url <- function(file_name) {
  sprintf(
    "https://github.com/%s/releases/download/%s/%s",
    GITHUB_CACHE_REPO,
    GITHUB_CACHE_TAG,
    file_name
  )
}

# In-session memo ------------------------------------------------------------

# Holds deserialised datasets keyed by their cache name so repeated calls
# within one R session do not re-download. In-memory only — cleared when
# the session ends.
.session_cache <- new.env(parent = emptyenv())

#' @noRd
memo_get <- function(key) {
  if (exists(key, envir = .session_cache, inherits = FALSE)) {
    return(get(key, envir = .session_cache))
  }
  return(NULL)
}

#' @noRd
memo_set <- function(key, value) {
  assign(key, value, envir = .session_cache)
  invisible(value)
}

#' Clear the In-Session Dataset Memo
#'
#' Drops every dataset memoised during the current R session. Useful when
#' iterating during development or to force re-fetch without restarting R.
#'
#' @return `NULL`, invisibly.
#' @export
#' @examplesIf interactive()
#' clear_session_cache()
clear_session_cache <- function() {
  rm(list = ls(.session_cache), envir = .session_cache)
  invisible()
}

# Fetch from GitHub release --------------------------------------------------

#' Fetch a Cache Asset from GitHub Releases
#'
#' Downloads a single asset from the package's `cache-latest` release into a
#' tempfile, reads it, and returns the deserialised object. Tries `.rds`
#' first, then `.csv.gz`. Returns `NULL` on miss (either format missing, the
#' release does not exist, or network failure).
#'
#' @param cached_name Character. Asset stem, e.g. `"abecip_sbpe"`.
#' @param quiet Logical. Suppress informational messages.
#'
#' @return The deserialised dataset, or `NULL`.
#' @keywords internal
fetch_github_release_asset <- function(cached_name, quiet = FALSE) {
  for (ext in c("rds", "csv.gz")) {
    file_name <- paste0(cached_name, ".", ext)

    data <- try_release_asset(file_name, ext, quiet = quiet)
    if (!is.null(data)) {
      return(data)
    }
  }

  return(NULL)
}

#' Try a Single Release Asset
#'
#' Downloads one file to a tempfile and reads it. Returns `NULL` on any
#' failure (HTTP error, parse error, network down). Network errors are
#' surfaced via `cli::cli_warn()`; a 404 (asset format absent) is silent so
#' that callers can fall through to the next extension.
#'
#' @noRd
try_release_asset <- function(file_name, ext, quiet) {
  url <- github_release_url(file_name)
  temp_path <- tempfile(fileext = paste0(".", ext))
  on.exit(unlink(temp_path), add = TRUE)

  if (!quiet) {
    cli::cli_inform("Fetching {file_name} from GitHub releases...")
  }

  response <- rlang::try_fetch(
    httr::GET(
      url,
      httr::write_disk(temp_path, overwrite = TRUE),
      httr::user_agent("realestatebr R package")
    ),
    error = function(cnd) {
      if (!quiet) {
        cli::cli_warn("Network error fetching {file_name}: {cnd$message}")
      }
      NULL
    }
  )

  if (is.null(response) || httr::http_error(response)) {
    return(NULL)
  }

  data <- rlang::try_fetch(
    if (ext == "rds") {
      readRDS(temp_path)
    } else {
      readr::read_delim(temp_path, show_col_types = FALSE)
    },
    error = function(cnd) {
      if (!quiet) {
        cli::cli_warn("Failed to parse {file_name}: {cnd$message}")
      }
      NULL
    }
  )

  if (!is.null(data) && !quiet) {
    cli::cli_inform("Loaded {file_name} from GitHub releases")
  }

  return(data)
}
