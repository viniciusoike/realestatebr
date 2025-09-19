# data-raw/update_data.R
# Phase 2: Simplified data update script using targets pipeline only

# Load required packages
library(targets)
library(tarchetypes)
library(cli)

# Check if targets infrastructure exists
if (!file.exists("_targets.R")) {
  cli::cli_abort(c(
    "No targets pipeline found",
    "x" = "_targets.R file is missing",
    "i" = "This script requires the Phase 2 targets pipeline to be set up"
  ))
}

# Create log directory
log_dir <- "logs"
dir.create(log_dir, showWarnings = FALSE)
log_file <- file.path(log_dir, format(Sys.time(), "update_log_%Y%m%d.txt"))

# Logging function
log_message <- function(msg) {
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  full_msg <- paste(timestamp, msg)
  message(full_msg)
  cat(full_msg, "\n", file = log_file, append = TRUE)
}

# Main execution
log_message("Starting data update process using targets pipeline")

tryCatch({
  # Run the full pipeline
  cli::cli_h1("Running targets pipeline")
  tar_make()

  # Generate status report
  if (file.exists("data-raw/generate_report.R")) {
    source("data-raw/generate_report.R")
    generate_pipeline_report()
  }

  log_message("Targets pipeline completed successfully")
  cli::cli_alert_success("Pipeline completed using targets")

}, error = function(e) {
  log_message(sprintf("Targets pipeline failed: %s", e$message))
  cli::cli_alert_danger("Targets pipeline failed: {e$message}")
  stop(e)
})

log_message("Data update process completed")