#' GitHub Release Cache Management
#'
#' Functions for downloading cached datasets from GitHub releases.
#' These functions provide a middle-ground between local cache and fresh downloads,
#' offering pre-processed data that's updated weekly via CI/CD.
#'
#' @name cache-github
NULL

#' Check if piggyback is Available
#'
#' Checks if the piggyback package is installed and available for use.
#'
#' @return Logical. TRUE if piggyback is available
#' @keywords internal
has_piggyback <- function() {
  requireNamespace("piggyback", quietly = TRUE)
}

#' Check GitHub Connection
#'
#' Tests if GitHub is accessible for downloading release assets.
#'
#' @return Logical. TRUE if GitHub is accessible
#' @keywords internal
check_github_available <- function() {
  tryCatch({
    response <- httr::HEAD("https://api.github.com", httr::timeout(5))
    return(httr::status_code(response) < 400)
  }, error = function(e) {
    return(FALSE)
  })
}

#' Get GitHub Repository Information
#'
#' Returns the GitHub repository information for this package.
#'
#' @return Character. GitHub repo in format "owner/repo"
#' @keywords internal
get_github_repo <- function() {
  # This should match your actual repository
  # You can also read from DESCRIPTION URL field
  return("viniciusoike/realestatebr")
}

#' Get GitHub Release Tag for Cache
#'
#' Returns the tag name for the release containing cached data.
#'
#' @return Character. Release tag name
#' @keywords internal
get_cache_release_tag <- function() {
  # Use "cache-latest" for rolling updates
  # Or use versioned tags like "v0.5.0-data"
  return("cache-latest")
}

#' List Available GitHub Assets
#'
#' Lists all cached datasets available on GitHub releases.
#'
#' @param quiet Logical. Suppress messages
#' @return Character vector of available asset names, or NULL if unavailable
#' @export
#'
#' @examples
#' \dontrun{
#' assets <- list_github_assets()
#' print(assets)
#' }
list_github_assets <- function(quiet = FALSE) {
  if (!has_piggyback()) {
    if (!quiet) {
      cli::cli_warn(c(
        "Package 'piggyback' not installed",
        "i" = "Install with: install.packages('piggyback')"
      ))
    }
    return(NULL)
  }

  if (!check_github_available()) {
    if (!quiet) {
      cli::cli_warn("GitHub is not accessible")
    }
    return(NULL)
  }

  repo <- get_github_repo()
  tag <- get_cache_release_tag()

  tryCatch({
    assets <- piggyback::pb_list(repo = repo, tag = tag)

    if (!quiet) {
      cli::cli_inform("Found {nrow(assets)} asset{?s} on GitHub release '{tag}'")
    }

    return(assets$file_name)

  }, error = function(e) {
    if (!quiet) {
      cli::cli_warn("Failed to list GitHub assets: {e$message}")
    }
    return(NULL)
  })
}

#' Download Dataset from GitHub Release
#'
#' Downloads a cached dataset from GitHub releases and saves to user cache.
#'
#' @param dataset_name Character. Name of dataset to download
#' @param overwrite Logical. Overwrite existing cached file (default: FALSE)
#' @param quiet Logical. Suppress messages
#' @return Dataset or NULL if download fails
#' @keywords internal
#' @export
download_from_github_release <- function(dataset_name, overwrite = FALSE, quiet = FALSE) {
  # Check prerequisites
  if (!has_piggyback()) {
    cli::cli_abort(c(
      "Package 'piggyback' is required for GitHub downloads",
      "i" = "Install with: install.packages('piggyback')",
      "i" = "Or use source='fresh' to download from original source"
    ))
  }

  if (!check_github_available()) {
    cli::cli_abort(c(
      "GitHub is not accessible",
      "i" = "Check your internet connection",
      "i" = "Or use source='fresh' to download from original source"
    ))
  }

  # Check if already cached and not overwriting
  if (is_cached(dataset_name) && !overwrite) {
    if (!quiet) {
      cli::cli_inform("Dataset '{dataset_name}' already cached. Loading from cache...")
    }
    return(load_from_user_cache(dataset_name, quiet = quiet))
  }

  # Ensure cache directory exists
  cache_dir <- ensure_cache_dir()
  repo <- get_github_repo()
  tag <- get_cache_release_tag()

  # Try different file formats
  extensions <- c("rds", "csv.gz", "csv")
  downloaded <- FALSE

  for (ext in extensions) {
    file_name <- paste0(dataset_name, ".", ext)
    dest_path <- file.path(cache_dir, file_name)

    if (!quiet) {
      cli::cli_inform("Attempting to download {file_name} from GitHub...")
    }

    tryCatch({
      piggyback::pb_download(
        file = file_name,
        repo = repo,
        tag = tag,
        dest = cache_dir,
        overwrite = overwrite
      )

      if (file.exists(dest_path)) {
        downloaded <- TRUE
        if (!quiet) {
          file_size <- file.info(dest_path)$size / 1024^2
          cli::cli_inform("Downloaded {file_name} ({round(file_size, 2)} MB)")
        }

        # Save metadata
        save_cache_metadata(dataset_name, ext, source = "github")

        # Load and return
        return(load_from_user_cache(dataset_name, quiet = quiet))
      }

    }, error = function(e) {
      # File doesn't exist in this format, try next
      if (!quiet && ext == extensions[length(extensions)]) {
        # Only warn on last attempt
        cli::cli_warn("Failed to download {file_name}: {e$message}")
      }
    })
  }

  if (!downloaded) {
    cli::cli_abort(c(
      "Dataset '{dataset_name}' not found on GitHub releases",
      "i" = "Available datasets: {paste(list_github_assets(quiet = TRUE), collapse = ', ')}",
      "i" = "Or use source='fresh' to download from original source"
    ))
  }

  return(NULL)
}

#' Download and Cache Dataset
#'
#' Unified function to download from GitHub and cache locally.
#' This is a convenience wrapper around download_from_github_release().
#'
#' @param dataset_name Character. Name of dataset
#' @param overwrite Logical. Overwrite existing cache
#' @param quiet Logical. Suppress messages
#' @return Dataset or NULL
#' @keywords internal
download_and_cache <- function(dataset_name, overwrite = FALSE, quiet = FALSE) {
  download_from_github_release(dataset_name, overwrite, quiet)
}

#' Check if GitHub Cache is Up to Date
#'
#' Compares local cache timestamp with GitHub release timestamp.
#'
#' @param dataset_name Character. Name of dataset
#' @return Logical. TRUE if local cache is up to date, FALSE if GitHub is newer, NA if can't determine
#' @keywords internal
#' @export
is_cache_up_to_date <- function(dataset_name) {
  if (!is_cached(dataset_name)) {
    return(FALSE)
  }

  if (!has_piggyback() || !check_github_available()) {
    return(NA)
  }

  repo <- get_github_repo()
  tag <- get_cache_release_tag()

  tryCatch({
    # Get GitHub asset info
    assets <- piggyback::pb_list(repo = repo, tag = tag)

    # Find matching file (try all extensions)
    extensions <- c("rds", "csv.gz", "csv")
    github_time <- NULL

    for (ext in extensions) {
      file_name <- paste0(dataset_name, ".", ext)
      asset_row <- assets[assets$file_name == file_name, ]

      if (nrow(asset_row) > 0) {
        github_time <- asset_row$timestamp[1]
        break
      }
    }

    if (is.null(github_time)) {
      return(NA)
    }

    # Get local cache time
    local_metadata <- get_cache_metadata(dataset_name)
    if (is.null(local_metadata) || is.null(local_metadata$cached_at)) {
      return(FALSE)
    }

    local_time <- local_metadata$cached_at

    # Compare timestamps
    return(local_time >= github_time)

  }, error = function(e) {
    return(NA)
  })
}

#' Update Cache from GitHub
#'
#' Updates local cache for specific datasets if GitHub has newer versions.
#'
#' @param dataset_names Character vector. Datasets to update, or NULL for all
#' @param quiet Logical. Suppress messages
#' @return Named logical vector indicating success/failure for each dataset
#' @importFrom stats setNames
#' @export
#'
#' @examples
#' \dontrun{
#' # Update specific datasets
#' update_cache_from_github(c("abecip", "bcb_series"))
#'
#' # Update all cached datasets
#' update_cache_from_github()
#' }
update_cache_from_github <- function(dataset_names = NULL, quiet = FALSE) {
  if (!has_piggyback()) {
    cli::cli_abort(c(
      "Package 'piggyback' is required for GitHub updates",
      "i" = "Install with: install.packages('piggyback')"
    ))
  }

  if (is.null(dataset_names)) {
    # Get all currently cached datasets
    cached_files <- list_cached_files()
    if (nrow(cached_files) == 0) {
      cli::cli_inform("No cached datasets to update")
      return(logical(0))
    }
    dataset_names <- cached_files$dataset
  }

  results <- setNames(logical(length(dataset_names)), dataset_names)

  for (dataset in dataset_names) {
    up_to_date <- is_cache_up_to_date(dataset)

    if (is.na(up_to_date)) {
      if (!quiet) {
        cli::cli_inform("Skipping {dataset}: cannot determine if update needed")
      }
      results[dataset] <- NA
    } else if (up_to_date) {
      if (!quiet) {
        cli::cli_inform("Skipping {dataset}: already up to date")
      }
      results[dataset] <- TRUE
    } else {
      if (!quiet) {
        cli::cli_inform("Updating {dataset} from GitHub...")
      }
      data <- download_from_github_release(dataset, overwrite = TRUE, quiet = quiet)
      results[dataset] <- !is.null(data)
    }
  }

  updated_count <- sum(results, na.rm = TRUE)
  if (!quiet) {
    cli::cli_inform("Updated {updated_count} dataset{?s}")
  }

  return(results)
}
