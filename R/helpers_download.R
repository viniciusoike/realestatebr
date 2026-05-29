# Download with retry --------------------------------------------------------

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
  desc = "Download"
) {
  for (i in seq_len(max_retries + 1)) {
    result <- rlang::try_fetch(fn(), error = function(cnd) {
      if (i <= max_retries && !quiet) {
        cli::cli_warn(
          "{desc} attempt {i}/{max_retries + 1} failed: {cnd$message}"
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

# Excel download -------------------------------------------------------------

#' Download and Validate Excel File
#'
#' Downloads an Excel file with validation of expected sheets and file size.
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
  quiet = FALSE
) {
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
          file_size,
          min_size
        ))
      }

      # Validate Excel sheets if specified
      if (!is.null(expected_sheets)) {
        sheets <- rlang::try_fetch(
          readxl::excel_sheets(temp_path),
          error = function(cnd) {
            rlang::abort("Downloaded file is not a valid Excel file", parent = cnd)
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

# CSV download ---------------------------------------------------------------

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
  quiet = FALSE
) {
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
      rlang::try_fetch(
        utils::download.file(url = url, destfile = temp_path, mode = "wb", quiet = TRUE),
        error = function(cnd) rlang::abort("Download failed", parent = cnd)
      )

      # Validate file size
      file_size <- file.size(temp_path)
      if (is.na(file_size) || file_size < min_size) {
        stop(sprintf(
          "Downloaded file too small: %s bytes (minimum: %s)",
          file_size,
          min_size
        ))
      }

      return(temp_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Download CSV file"
  )
}

# ZIP download ---------------------------------------------------------------

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
  quiet = FALSE
) {
  download_with_retry(
    fn = function() {
      # Configure SSL if needed
      if (!ssl_verify) {
        httr::set_config(httr::config(ssl_verifypeer = 0L))
        on.exit(httr::reset_config(), add = TRUE)
      }

      # Download ZIP to temp file
      temp_zip <- tempfile(fileext = ".zip")

      rlang::try_fetch(
        utils::download.file(url = url, destfile = temp_zip, mode = "wb", quiet = TRUE),
        error = function(cnd) rlang::abort("ZIP download failed", parent = cnd)
      )

      # Extract to a dedicated temp directory (avoids stale file conflicts)
      extract_dir <- tempfile(pattern = "zip_extract_")
      dir.create(extract_dir, recursive = TRUE)

      utils::unzip(temp_zip, exdir = extract_dir)

      # Find target file
      all_files <- list.files(
        extract_dir,
        pattern = file_pattern,
        recursive = TRUE,
        full.names = TRUE
      )

      if (length(all_files) == 0) {
        stop(
          "No file matching pattern '",
          file_pattern,
          "' found in ZIP archive"
        )
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
          stop(
            "Multiple files match pattern and cannot disambiguate: ",
            paste(basename(all_files), collapse = ", ")
          )
        }
      }

      csv_path <- all_files[1]

      # Validate file size
      file_size <- file.size(csv_path)
      if (is.na(file_size) || file_size < min_size) {
        stop(sprintf(
          "Extracted file too small: %s bytes (minimum: %s)",
          file_size,
          min_size
        ))
      }

      return(csv_path)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "Download ZIP file"
  )
}

# GitHub cache fallback -------------------------------------------------------

#' Fallback to GitHub Release on Download Failure
#'
#' Attempts to load a dataset from the package's GitHub release when a primary
#' web download has failed. Returns NULL on miss so callers can decide whether
#' to abort or degrade gracefully.
#'
#' @param dataset_name Character. Asset stem used in the GitHub release (e.g.,
#'   `"bcb_realestate"`, `"secovi_sp"`).
#' @param quiet Logical. If TRUE, suppresses messages.
#'
#' @return A tibble if the GitHub release asset is available, otherwise NULL.
#' @keywords internal
fallback_to_github_cache <- function(dataset_name, quiet = FALSE) {
  if (!quiet) {
    cli::cli_inform(c("i" = "Trying GitHub release for {.val {dataset_name}}..."))
  }

  data <- fetch_github_release_asset(dataset_name, quiet = quiet)

  if (!is.null(data) && is.data.frame(data) && nrow(data) > 0) {
    return(data)
  }

  return(NULL)
}
