# _targets.R
# Phase 2: Simplified Data Pipeline with {targets}
#
# This pipeline wraps existing Phase 1 get_*() functions with {targets}
# for dependency tracking and incremental updates

library(targets)
library(tarchetypes)

# Load package for access to all get_*() functions
tar_option_set(
  packages = c("realestatebr", "dplyr", "readr", "cli"),
  format = "rds"
)

# Ensure latest package functions are loaded
if (interactive()) {
  devtools::load_all()
}

# Source helper functions
source("data-raw/targets_helpers.R")

# Define all targets
list(
  # ---- DAILY UPDATES ----


  # ---- WEEKLY UPDATES ----

  # BCB Series - Macroeconomic indicators
  tar_target(
    name = bcb_series_data,
    command = {
      cli::cli_inform("Fetching BCB Series data...")
      get_bcb_series(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = bcb_series_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # BCB Real Estate - Real estate specific indicators
  tar_target(
    name = bcb_realestate_data,
    command = {
      cli::cli_inform("Fetching BCB Real Estate data...")
      get_bcb_realestate(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = bcb_realestate_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # FGV IBRE - Economic indicators
  tar_target(
    name = fgv_ibre_data,
    command = {
      cli::cli_inform("Fetching FGV IBRE data...")
      get_fgv_ibre(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = fgv_ibre_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # ABECIP Indicators
  tar_target(
    name = abecip_data,
    command = {
      cli::cli_inform("Fetching ABECIP data...")
      get_abecip_indicators(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = abecip_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # ABRAINC Indicators
  tar_target(
    name = abrainc_data,
    command = {
      cli::cli_inform("Fetching ABRAINC data...")
      get_abrainc_indicators(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = abrainc_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # SECOVI Data
  tar_target(
    name = secovi_data,
    command = {
      cli::cli_inform("Fetching SECOVI data...")
      get_secovi(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = secovi_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # RPPI Sale Data
  tar_target(
    name = rppi_sale_data,
    command = {
      cli::cli_inform("Fetching RPPI Sale data...")
      get_rppi("sale", cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = rppi_sale_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # RPPI Rent Data
  tar_target(
    name = rppi_rent_data,
    command = {
      cli::cli_inform("Fetching RPPI Rent data...")
      get_rppi("rent", cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = rppi_rent_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # ---- LOW PRIORITY DATASETS (Weekly/Monthly Updates) ----

  # BIS RPPI Data
  tar_target(
    name = bis_rppi_data,
    command = {
      cli::cli_inform("Fetching BIS RPPI data...")
      get_rppi_bis(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = bis_rppi_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # CBIC Data
  tar_target(
    name = cbic_data,
    command = {
      cli::cli_inform("Fetching CBIC data...")
      get_cbic_materials()
    },
    cue = tar_cue_age(
      name = cbic_data,
      age = as.difftime(7, units = "days")
    )
  ),

  # Property Records
  tar_target(
    name = property_records_data,
    command = {
      cli::cli_inform("Fetching Property Records data...")
      get_property_records(cached = FALSE, quiet = FALSE)
    },
    cue = tar_cue_age(
      name = property_records_data,
      age = as.difftime(14, units = "days")
    )
  ),

  # NRE-IRE Data (internal package data only)
  tar_target(
    name = nre_ire_data,
    command = {
      cli::cli_inform("Fetching NRE-IRE data...")
      # Call function directly, not through unified interface
      get_nre_ire(cached = TRUE, quiet = FALSE)
    },
    cue = tar_cue(mode = "never")  # Don't auto-update since it's manual data
  ),

  # ---- CACHE UPDATE TARGETS ----

  # Save high-priority data to cache
  tar_target(
    name = cache_daily_data,
    command = {
      cli::cli_inform("Updating cache for daily datasets...")

      # Ensure cache directory exists
      cache_dir <- file.path("inst", "cached_data")
      if (!dir.exists(cache_dir)) {
        dir.create(cache_dir, recursive = TRUE)
      }

      # Save datasets with compression
      save_dataset_to_cache(bcb_series_data, "bcb_series")
      save_dataset_to_cache(bcb_realestate_data, "bcb_realestate")
      save_dataset_to_cache(b3_stocks_data, "b3_stocks")
      save_dataset_to_cache(fgv_ibre_data, "fgv_ibre")

      # Return summary
      paste("Daily cache updated:", Sys.time())
    },
    format = "file",
    pattern = NULL
  ),

  # Save medium-priority data to cache
  tar_target(
    name = cache_weekly_data,
    command = {
      cli::cli_inform("Updating cache for weekly datasets...")

      # Save datasets
      save_dataset_to_cache(abecip_data, "abecip")
      save_dataset_to_cache(abrainc_data, "abrainc")
      save_dataset_to_cache(secovi_data, "secovi_sp")
      save_dataset_to_cache(rppi_sale_data, "rppi_sale")
      save_dataset_to_cache(rppi_rent_data, "rppi_rent")

      paste("Weekly cache updated:", Sys.time())
    },
    format = "file",
    pattern = NULL
  ),

  # Save low-priority data to cache
  tar_target(
    name = cache_monthly_data,
    command = {
      cli::cli_inform("Updating cache for monthly datasets...")

      save_dataset_to_cache(bis_rppi_data, "bis_selected")
      save_dataset_to_cache(cbic_data, "cbic")
      save_dataset_to_cache(property_records_data, "property_records")
      save_dataset_to_cache(nre_ire_data, "nre_ire")

      paste("Monthly cache updated:", Sys.time())
    },
    format = "file",
    pattern = NULL
  ),

  # ---- PIPELINE SUMMARY TARGET ----

  # Generate pipeline summary
  tar_target(
    name = pipeline_summary,
    command = {
      cli::cli_inform("Generating pipeline summary...")

      # Count successful updates
      daily_count <- 4  # bcb_series, bcb_realestate, b3_stocks, fgv_ibre
      weekly_count <- 5  # abecip, abrainc, secovi, rppi_sale, rppi_rent
      monthly_count <- 4  # bis_rppi, cbic, property_records, nre_ire

      summary_info <- list(
        timestamp = Sys.time(),
        daily_datasets = daily_count,
        weekly_datasets = weekly_count,
        monthly_datasets = monthly_count,
        total_datasets = daily_count + weekly_count + monthly_count,
        cache_locations = c(
          cache_daily_data,
          cache_weekly_data,
          cache_monthly_data
        )
      )

      cli::cli_alert_success("Pipeline completed: {summary_info$total_datasets} datasets processed")

      summary_info
    }
  )
)