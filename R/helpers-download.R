# Generic Helper Functions for Download Operations
# Created: 2025-12-16 (v0.6.x)
# Purpose: Consolidate repetitive download logic across dataset functions

# ==============================================================================
# HELPER 1: DOWNLOAD WITH RETRY
# ==============================================================================

#' Download with Retry Logic
#'
#' Executes a download function with automatic retry on failure.
#' Uses exponential backoff between retry attempts.
#'
#' @param fn Function to execute (should return data on success)
#' @param max_retries Maximum number of retry attempts
#' @param quiet If TRUE, suppresses retry warnings
#' @param desc Description of what's being downloaded (for error messages)
#'
#' @return Result from fn() if successful
#'
#' @keywords internal
download_with_retry <- function(
    fn,
    max_retries = 3,
    quiet = FALSE,
    desc = "Download") {
  for (i in seq_len(max_retries + 1)) {
    result <- tryCatch(fn(), error = function(e) {
      if (i <= max_retries && !quiet) {
        cli::cli_warn(
          "{desc} attempt {i}/{max_retries + 1} failed: {e$message}"
        )
      }
      NULL
    })
    if (!is.null(result)) {
      return(result)
    }
    if (i <= max_retries) Sys.sleep(min(i * 0.5, 3))
  }
  cli::cli_abort("{desc} failed after {max_retries + 1} attempts")
}

# ==============================================================================
# HELPER 2: CORE FILE DOWNLOAD
# ==============================================================================

#' Download File to Temporary Location
#'
#' Downloads a file from a URL to a temporary location with retry logic.
#' This is the core download function used by format-specific helpers.
#'
#' @param url Character. URL to download from.
#' @param file_ext Character. File extension (e.g., ".xlsx", ".csv").
#' @param ssl_verify Logical. Whether to verify SSL certificates.
#'   Set to FALSE for sites with problematic certificates.
#' @param max_retries Integer. Number of retry attempts.
#' @param quiet Logical. Suppress progress messages.
#' @param desc Character. Description for error messages.
#'
#' @return Character. Path to downloaded temp file.
#'
#' @details
#' The function downloads to a temporary file created with `tempfile()`.
#' The temp file will be cleaned up by R's session cleanup, but callers
#' can explicitly `unlink()` if needed.
#'
#' @keywords internal
download_file <- function(
    url,
    file_ext = ".xlsx",
    ssl_verify = TRUE,
    max_retries = 3,
    quiet = FALSE,
    desc = "file") {
  download_with_retry(
    fn = function() {
      # Configure SSL if needed
      if (!ssl_verify) {
        httr::set_config(httr::config(ssl_verifypeer = 0L))
        on.exit(httr::reset_config(), add = TRUE)
      }

      # Create temp file
      temp_path <- tempfile(fileext = file_ext)

      # Download
      response <- httr::GET(
        url = url,
        httr::write_disk(path = temp_path, overwrite = TRUE)
      )

      # Check HTTP status
      httr::stop_for_status(response)

      # Verify file exists and has content
      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty or missing")
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = paste("Download", desc)
  )
}

# ==============================================================================
# HELPER 3: EXCEL DOWNLOAD
# ==============================================================================

#' Download and Validate Excel File
#'
#' Downloads an Excel file with validation of expected sheets and file size.
#' Combines download_file() with validate_excel_file() from helpers-dataset.R.
#'
#' @param url Character. URL of the Excel file.
#' @param expected_sheets Character vector. Sheet names that must be present.
#'   If NULL, no sheet validation is performed.
#' @param min_size Integer. Minimum file size in bytes. Default 1000.
#' @param ssl_verify Logical. Whether to verify SSL certificates.
#' @param max_retries Integer. Number of retry attempts.
#' @param quiet Logical. Suppress progress messages.
#'
#' @return Character. Path to downloaded and validated Excel file.
#'
#' @keywords internal
download_excel <- function(
    url,
    expected_sheets = NULL,
    min_size = 1000,
    ssl_verify = TRUE,
    max_retries = 3,
    quiet = FALSE) {
  download_with_retry(
    fn = function() {
      # Configure SSL if needed
      if (!ssl_verify) {
        httr::set_config(httr::config(ssl_verifypeer = 0L))
        on.exit(httr::reset_config(), add = TRUE)
      }

      # Create temp file with xlsx extension
      temp_path <- tempfile(fileext = ".xlsx")

      # Download
      response <- httr::GET(
        url = url,
        httr::write_disk(path = temp_path, overwrite = TRUE)
      )

      # Check HTTP status
      httr::stop_for_status(response)

      # Validate file size
      file_size <- file.size(temp_path)
      if (is.na(file_size) || file_size < min_size) {
        stop(sprintf(
          "Downloaded file too small: %s bytes (minimum: %s)",
          file_size, min_size
        ))
      }

      # Validate Excel sheets if specified
      if (!is.null(expected_sheets)) {
        sheets <- tryCatch(
          readxl::excel_sheets(temp_path),
          error = function(e) {
            stop("Downloaded file is not a valid Excel file: ", e$message)
          }
        )

        missing_sheets <- setdiff(expected_sheets, sheets)
        if (length(missing_sheets) > 0) {
          stop(sprintf(
            "Missing expected sheets: %s. Available: %s",
            paste(missing_sheets, collapse = ", "),
            paste(sheets, collapse = ", ")
          ))
        }
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Download Excel file"
  )
}

# ==============================================================================
# HELPER 4: CSV DOWNLOAD
# ==============================================================================

#' Download CSV File
#'
#' Downloads a CSV file to a temporary location with retry logic.
#'
#' @param url Character. URL of the CSV file.
#' @param min_size Integer. Minimum file size in bytes. Default 100.
#' @param ssl_verify Logical. Whether to verify SSL certificates.
#' @param max_retries Integer. Number of retry attempts.
#' @param quiet Logical. Suppress progress messages.
#'
#' @return Character. Path to downloaded CSV file.
#'
#' @keywords internal
download_csv <- function(
    url,
    min_size = 100,
    ssl_verify = TRUE,
    max_retries = 3,
    quiet = FALSE) {
  download_with_retry(
    fn = function() {
      # Configure SSL if needed
      if (!ssl_verify) {
        httr::set_config(httr::config(ssl_verifypeer = 0L))
        on.exit(httr::reset_config(), add = TRUE)
      }

      # Create temp file with csv extension
      temp_path <- tempfile(fileext = ".csv")

      # Download using utils::download.file for CSV (more robust for text files)
      result <- tryCatch(
        {
          utils::download.file(
            url = url,
            destfile = temp_path,
            mode = "wb",
            quiet = TRUE
          )
          0
        },
        error = function(e) 1
      )

      if (result != 0) {
        stop("Download failed")
      }

      # Validate file size
      file_size <- file.size(temp_path)
      if (is.na(file_size) || file_size < min_size) {
        stop(sprintf(
          "Downloaded file too small: %s bytes (minimum: %s)",
          file_size, min_size
        ))
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Download CSV file"
  )
}

# ==============================================================================
# HELPER 4b: ZIP DOWNLOAD
# ==============================================================================

#' Download and Extract File from ZIP Archive
#'
#' Downloads a ZIP archive, extracts a file matching `file_pattern`,
#' validates its size, and returns the path to the extracted file.
#'
#' @param url Character. URL of the ZIP archive.
#' @param file_pattern Character. Regex pattern to match the target file
#'   inside the archive. Default `"\\.csv$"`.
#' @param min_size Integer. Minimum extracted file size in bytes. Default 1000.
#' @param ssl_verify Logical. Whether to verify SSL certificates.
#' @param max_retries Integer. Number of retry attempts.
#' @param quiet Logical. Suppress progress messages.
#'
#' @return Character. Path to the extracted file.
#'
#' @keywords internal
download_zip <- function(
    url,
    file_pattern = "\\.csv$",
    min_size = 1000,
    ssl_verify = TRUE,
    max_retries = 3,
    quiet = FALSE) {
  download_with_retry(
    fn = function() {
      # Configure SSL if needed
      if (!ssl_verify) {
        httr::set_config(httr::config(ssl_verifypeer = 0L))
        on.exit(httr::reset_config(), add = TRUE)
      }

      # Download ZIP to temp file
      temp_zip <- tempfile(fileext = ".zip")

      result <- tryCatch(
        {
          utils::download.file(
            url = url,
            destfile = temp_zip,
            mode = "wb",
            quiet = TRUE
          )
          0
        },
        error = function(e) 1
      )

      if (result != 0) {
        stop("ZIP download failed")
      }

      # Extract to a dedicated temp directory (avoids stale file conflicts)
      extract_dir <- tempfile(pattern = "zip_extract_")
      dir.create(extract_dir, recursive = TRUE)

      utils::unzip(temp_zip, exdir = extract_dir)

      # Find target file
      all_files <- list.files(extract_dir, pattern = file_pattern,
                              recursive = TRUE, full.names = TRUE)

      if (length(all_files) == 0) {
        stop("No file matching pattern '", file_pattern,
             "' found in ZIP archive")
      }

      # Disambiguate using basename of URL if multiple matches
      if (length(all_files) > 1) {
        basename_stem <- stringr::str_remove(basename(url), "\\.zip$")
        matched <- all_files[
          stringr::str_detect(basename(all_files), basename_stem)
        ]

        if (length(matched) == 1) {
          all_files <- matched
        } else {
          stop("Multiple files match pattern and cannot disambiguate: ",
               paste(basename(all_files), collapse = ", "))
        }
      }

      csv_path <- all_files[1]

      # Validate file size
      file_size <- file.size(csv_path)
      if (is.na(file_size) || file_size < min_size) {
        stop(sprintf(
          "Extracted file too small: %s bytes (minimum: %s)",
          file_size, min_size
        ))
      }

      return(csv_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Download ZIP file"
  )
}

# ==============================================================================
# HELPER 5: URL EXTRACTION FROM WEB PAGE
# ==============================================================================

#' Extract Download URL from Web Page
#'
#' Scrapes a web page to find a download link using XPath or CSS selector.
#' Useful for datasets where the download URL is embedded in a web page.
#'
#' @param page_url Character. URL of the page containing the download link.
#' @param xpath Character. XPath selector for the download link element.
#'   Should select an element with an `href` attribute.
#' @param css Character. CSS selector (alternative to xpath).
#'   Use either xpath or css, not both.
#' @param base_url Character. Base URL to prepend if link is relative.
#'   If NULL, attempts to extract from page_url.
#' @param max_retries Integer. Number of retry attempts.
#' @param quiet Logical. Suppress progress messages.
#'
#' @return Character. Full download URL.
#'
#' @details
#' This function only extracts the URL - it does not download the file.
#' Use download_excel() or download_file() to download the extracted URL.
#'
#' @keywords internal
scrape_download_url <- function(
    page_url,
    xpath = NULL,
    css = NULL,
    base_url = NULL,
    max_retries = 3,
    quiet = FALSE) {
  # Validate inputs

if (is.null(xpath) && is.null(css)) {
    cli::cli_abort("Either {.arg xpath} or {.arg css} must be provided")
  }

  download_with_retry(
    fn = function() {
      # Read the page
      page <- xml2::read_html(page_url)

      # Extract link using xpath or css
      if (!is.null(xpath)) {
        link_elem <- rvest::html_elements(page, xpath = xpath)
      } else {
        link_elem <- rvest::html_elements(page, css = css)
      }

      if (length(link_elem) == 0) {
        stop("Download link not found on page")
      }

      # Get href attribute
      url <- rvest::html_attr(link_elem[1], "href")

      if (is.na(url) || url == "") {
        stop("Download link element has no href attribute")
      }

      # Handle relative URLs
      if (!grepl("^https?://", url)) {
        if (is.null(base_url)) {
          # Extract base URL from page URL
          parsed <- httr::parse_url(page_url)
          base_url <- paste0(parsed$scheme, "://", parsed$hostname)
        }

        # Ensure proper joining
        if (!grepl("^/", url)) {
          url <- paste0("/", url)
        }
        url <- paste0(base_url, url)
      }

      return(url)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Extract download URL"
  )
}

# ==============================================================================
# HELPER 6: DOWNLOAD MULTIPLE FILES
# ==============================================================================

#' Download Multiple Files with Progress
#'
#' Downloads multiple files from a list of URLs with progress reporting.
#' Useful for datasets with multiple source files (e.g., CBIC materials).
#'
#' @param urls Character vector. URLs to download.
#' @param file_ext Character. File extension for all files.
#' @param delay Numeric. Seconds to wait between downloads (rate limiting).
#' @param ssl_verify Logical. Whether to verify SSL certificates.
#' @param max_retries Integer. Number of retry attempts per file.
#' @param quiet Logical. Suppress progress messages.
#'
#' @return List with two elements:
#'   - paths: Character vector of successful download paths
#'   - failed: Character vector of URLs that failed to download
#'
#' @keywords internal
download_multiple_files <- function(
    urls,
    file_ext = ".xlsx",
    delay = 1,
    ssl_verify = TRUE,
    max_retries = 3,
    quiet = FALSE) {
  paths <- character(length(urls))
  failed <- character()

  for (i in seq_along(urls)) {
    if (!quiet && length(urls) > 1) {
      cli::cli_inform("Downloading file {i}/{length(urls)}...")
    }

    result <- tryCatch(
      {
        path <- download_file(
          url = urls[i],
          file_ext = file_ext,
          ssl_verify = ssl_verify,
          max_retries = max_retries,
          quiet = TRUE  # Suppress individual file messages
        )
        paths[i] <- path
        NULL
      },
      error = function(e) {
        if (!quiet) {
          cli::cli_warn("Failed to download: {urls[i]}")
        }
        urls[i]
      }
    )

    if (!is.null(result)) {
      failed <- c(failed, result)
    }

    # Rate limiting between downloads
    if (i < length(urls) && delay > 0) {
      Sys.sleep(delay)
    }
  }

  # Remove empty paths from failed downloads
  paths <- paths[paths != ""]

  if (!quiet) {
    cli::cli_inform(
      "Downloaded {length(paths)}/{length(urls)} files successfully"
    )
    if (length(failed) > 0) {
      cli::cli_warn("{length(failed)} file{?s} failed to download")
    }
  }

  list(paths = paths, failed = failed)
}
