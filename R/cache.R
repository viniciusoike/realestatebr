#' Cache Management Utilities (DEPRECATED)
#'
#' These functions are deprecated as of version 0.5.0. Use the new user-level
#' cache functions instead (see \code{\link{cache-user}}).
#'
#' @name cache-deprecated
NULL

#' Import Cached Dataset (DEPRECATED)
#'
#' \strong{DEPRECATED}: This function loaded data from \code{inst/cached_data/}
#' which is no longer included in the package. Use \code{\link{load_from_user_cache}}
#' or \code{\link{get_dataset}} with \code{source="cache"} instead.
#'
#' @param dataset_name Character. Name of the cached dataset (without extension)
#' @param cache_dir Character. Path to cache directory (default: "cached_data")
#' @param format Character. File format ("auto", "rds", "csv"). If "auto",
#'   will try RDS first, then compressed CSV.
#' @param quiet Logical. Suppress informational messages (default: FALSE)
#'
#' @return Dataset as tibble or list, depending on original structure
#'
#' @seealso \code{\link{load_from_user_cache}}, \code{\link{get_dataset}}
#' @keywords internal
#' @export
import_cached <- function(dataset_name,
                         cache_dir = "cached_data",
                         format = "auto",
                         quiet = FALSE) {

  # Deprecation warning
  if (!quiet) {
    lifecycle::deprecate_warn(
      when = "0.5.0",
      what = "import_cached()",
      with = "load_from_user_cache()",
      details = "import_cached() now loads from user cache (~/.local/share/realestatebr/) instead of inst/cached_data/"
    )
  }

  # Validate inputs
  if (!is.character(dataset_name) || length(dataset_name) != 1 || dataset_name == "") {
    cli::cli_abort("dataset_name must be a non-empty character string")
  }

  # Redirect to new user cache system
  # Ignore cache_dir and format parameters (they're deprecated)
  return(load_from_user_cache(dataset_name, quiet = quiet))
}

