# Publish Cached Data to GitHub Releases
#
# This script uploads cached datasets from the targets pipeline to GitHub releases,
# making them available for users to download via the get_dataset() function with
# source = "github" or source = "auto".
#
# This script is designed to be run:
# 1. Manually after running targets::tar_make()
# 2. Automatically by GitHub Actions after weekly data updates
#
# Prerequisites:
# - piggyback package installed
# - GitHub authentication configured (via GITHUB_PAT or gh CLI)
# - Cached data files in inst/cached_data/

library(piggyback)
library(cli)

# Configuration ----
REPO <- "viniciusoike/realestatebr"  # Update with your actual repo
TAG <- "cache-latest"  # Rolling tag for latest cache
CACHE_DIR <- "inst/cached_data"

# GitHub Authentication ----
# The piggyback package will use:
# 1. GITHUB_PAT environment variable
# 2. gh CLI authentication
# 3. Interactive login

cli_h1("Publishing Cache to GitHub Releases")

# Check if piggyback is available
if (!requireNamespace("piggyback", quietly = TRUE)) {
  cli_abort(c(
    "Package 'piggyback' is required",
    "i" = "Install with: install.packages('piggyback')"
  ))
}

# Check authentication
auth_status <- tryCatch({
  pb_list(repo = REPO, tag = TAG)
  TRUE
}, error = function(e) {
  FALSE
})

if (!auth_status) {
  cli_alert_info("Setting up GitHub authentication...")
  # Try to setup authentication
  tryCatch({
    # This will prompt for GitHub token if not available
    Sys.setenv(GITHUB_PAT = readline("Enter your GitHub PAT: "))
  }, error = function(e) {
    cli_abort(c(
      "GitHub authentication failed",
      "i" = "Create a PAT at: https://github.com/settings/tokens",
      "i" = "Set GITHUB_PAT environment variable or use gh CLI: gh auth login"
    ))
  })
}

# Check if cache directory exists ----
if (!dir.exists(CACHE_DIR)) {
  cli_abort(c(
    "Cache directory not found: {CACHE_DIR}",
    "i" = "Run targets::tar_make() first to generate cached data"
  ))
}

# Get list of cache files to upload ----
cache_files <- list.files(
  CACHE_DIR,
  pattern = "\\.(rds|csv\\.gz|csv)$",
  full.names = TRUE
)

# Exclude metadata files (too small, not needed on GitHub)
cache_files <- cache_files[!grepl("_metadata\\.rds$", cache_files)]

if (length(cache_files) == 0) {
  cli_alert_warning("No cache files found to upload")
  quit(save = "no", status = 0)
}

cli_alert_info("Found {length(cache_files)} file{?s} to upload")

# Create or update release ----
cli_h2("Creating GitHub Release")

existing_releases <- tryCatch({
  pb_releases(repo = REPO)
}, error = function(e) {
  NULL
})

if (is.null(existing_releases) || !TAG %in% existing_releases$tag_name) {
  cli_alert_info("Creating new release: {TAG}")
  tryCatch({
    pb_new_release(
      repo = REPO,
      tag = TAG,
      name = "Cached Datasets (Latest)",
      body = paste(
        "# Cached Datasets",
        "",
        "Pre-processed datasets automatically updated by GitHub Actions.",
        "",
        "**Last Updated:** ", format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
        "",
        "## Usage",
        "",
        "These files are automatically downloaded when using:",
        "```r",
        "# Downloads from GitHub releases if not in local cache",
        "data <- get_dataset('dataset_name')",
        "",
        "# Force download from GitHub releases",
        "data <- get_dataset('dataset_name', source = 'github')",
        "```",
        "",
        "## Files",
        "",
        paste0("- ", length(cache_files), " dataset files"),
        "",
        "## Notes",
        "",
        "- Datasets are updated weekly via CI/CD",
        "- Files are compressed (RDS or CSV.GZ format)",
        "- Use `list_github_assets()` to see available datasets",
        sep = "\n"
      )
    )
  }, error = function(e) {
    cli_abort("Failed to create release: {e$message}")
  })
} else {
  cli_alert_info("Release {TAG} already exists")
}

# Upload files ----
cli_h2("Uploading Files")

upload_results <- list()
for (file in cache_files) {
  file_name <- basename(file)
  file_size_mb <- round(file.info(file)$size / 1024^2, 2)

  cli_alert_info("Uploading {file_name} ({file_size_mb} MB)...")

  result <- tryCatch({
    pb_upload(
      file = file,
      repo = REPO,
      tag = TAG,
      overwrite = TRUE,
      show_progress = TRUE
    )
    cli_alert_success("Uploaded {file_name}")
    list(file = file_name, status = "success", size_mb = file_size_mb)
  }, error = function(e) {
    cli_alert_danger("Failed to upload {file_name}: {e$message}")
    list(file = file_name, status = "failed", error = e$message)
  })

  upload_results[[file_name]] <- result
}

# Summary ----
cli_h2("Upload Summary")

success_count <- sum(sapply(upload_results, function(x) x$status == "success"))
total_count <- length(upload_results)

if (success_count == total_count) {
  cli_alert_success("Successfully uploaded all {total_count} file{?s}")
} else {
  cli_alert_warning("Uploaded {success_count}/{total_count} file{?s}")

  # Show failed files
  failed_files <- names(upload_results)[
    sapply(upload_results, function(x) x$status == "failed")
  ]
  if (length(failed_files) > 0) {
    cli_alert_danger("Failed files:")
    for (f in failed_files) {
      cli_alert_danger("  - {f}: {upload_results[[f]]$error}")
    }
  }
}

# Calculate total size
total_size_mb <- sum(sapply(
  upload_results[sapply(upload_results, function(x) x$status == "success")],
  function(x) x$size_mb
), na.rm = TRUE)

cli_alert_info("Total size uploaded: {round(total_size_mb, 2)} MB")

# Release URL
release_url <- paste0("https://github.com/", REPO, "/releases/tag/", TAG)
cli_alert_info("View release at: {release_url}")

# Exit with appropriate status code
if (success_count == total_count) {
  quit(save = "no", status = 0)
} else {
  quit(save = "no", status = 1)
}
