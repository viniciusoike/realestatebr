# _targets.R
# Modernized Data Pipeline using {targets}
#
# This pipeline uses the modern get_dataset() architecture to update
# cached data on a weekly schedule. It's designed to be:
# - Registry-driven: Uses inst/extdata/datasets.yaml as source of truth
# - Modular: Easy to add/remove datasets
# - Reliable: Proper error handling and validation
# - Maintainable: Clean separation of concerns

library(targets)
library(tarchetypes)

# Load package for access to get_dataset() and other functions
tar_option_set(
  packages = c("realestatebr", "dplyr", "readr", "cli"),
  format = "rds",
  error = "continue"  # Continue pipeline even if some targets fail
)

# Ensure latest package functions are loaded (always load development version)
devtools::load_all()

# Source helper functions
source("data-raw/pipeline/targets_helpers.R")
source("data-raw/pipeline/validation.R")

# ============================================================================
# HELPER FUNCTIONS FOR TARGETS
# ============================================================================

#' Fetch Dataset Using Modern Architecture
#'
#' Wrapper function that uses get_dataset() to download and return the latest
#' data for a given dataset. Uses appropriate source based on dataset capabilities.
#'
#' @param dataset_name Name of dataset (e.g., "abecip", "abrainc")
#' @param table Optional table within dataset
#' @param source Data source - "fresh" for downloadable datasets, "github" for manual-only
#' @return Dataset (tibble or list)
fetch_dataset <- function(dataset_name, table = NULL, source = "fresh") {
  cli::cli_inform("Fetching {dataset_name}{if(!is.null(table)) paste0(' (', table, ')') else ''}...")

  # Use get_dataset with specified source
  # Most datasets use source="fresh" for real-time downloads
  # Manually-updated datasets (FGV, NRE-IRE) use source="github" to access cache
  data <- get_dataset(
    name = dataset_name,
    table = table,
    source = source
  )

  cli::cli_alert_success("Fetched {dataset_name}")
  return(data)
}

#' Save Dataset to Cache and Return File Path
#'
#' Saves dataset to cache and returns the file path for targets tracking
#'
#' @param data Dataset to save
#' @param cache_name Name to use for cache file
#' @return Character string with file path
save_to_cache <- function(data, cache_name) {
  cli::cli_inform("Saving {cache_name} to cache...")

  # Use helper function from targets_helpers.R
  file_path <- save_dataset_to_cache(data, cache_name)

  cli::cli_alert_success("Saved {cache_name}")
  return(file_path)
}

# ============================================================================
# PIPELINE TARGETS
# ============================================================================

list(
  # ========================================================================
  # WEEKLY UPDATES - High-priority datasets updated every Monday
  # ========================================================================

  # ---- BCB Series - Macroeconomic Indicators ----
  tar_target(
    name = bcb_series_data,
    command = fetch_dataset("bcb_series"),
    cue = tar_cue_age(
      name = bcb_series_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = bcb_series_cache,
    command = save_to_cache(bcb_series_data, "bcb_series"),
    format = "file"
  ),
  tar_target(
    name = bcb_series_validation,
    command = validate_dataset(bcb_series_data, "bcb_series")
  ),

  # ---- BCB Real Estate - Real Estate Market Data ----
  tar_target(
    name = bcb_realestate_data,
    command = fetch_dataset("bcb_realestate"),
    cue = tar_cue_age(
      name = bcb_realestate_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = bcb_realestate_cache,
    command = save_to_cache(bcb_realestate_data, "bcb_realestate"),
    format = "file"
  ),
  tar_target(
    name = bcb_realestate_validation,
    command = validate_dataset(bcb_realestate_data, "bcb_realestate")
  ),

  # ---- FGV IBRE - Economic Indicators ----
  # NOTE: FGV data is manually updated (no API available)
  # Uses source="github" to access cached data
  tar_target(
    name = fgv_ibre_data,
    command = fetch_dataset("fgv_ibre", source = "github"),
    cue = tar_cue_age(
      name = fgv_ibre_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = fgv_ibre_cache,
    command = save_to_cache(fgv_ibre_data, "fgv_ibre"),
    format = "file"
  ),
  tar_target(
    name = fgv_ibre_validation,
    command = validate_dataset(fgv_ibre_data, "fgv_ibre")
  ),

  # ---- ABECIP - Housing Credit Indicators ----
  tar_target(
    name = abecip_data,
    command = fetch_dataset("abecip"),
    cue = tar_cue_age(
      name = abecip_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = abecip_cache,
    command = save_to_cache(abecip_data, "abecip"),
    format = "file"
  ),
  tar_target(
    name = abecip_validation,
    command = validate_dataset(abecip_data, "abecip")
  ),

  # ---- ABRAINC - Primary Market Indicators ----
  tar_target(
    name = abrainc_data,
    command = fetch_dataset("abrainc"),
    cue = tar_cue_age(
      name = abrainc_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = abrainc_cache,
    command = save_to_cache(abrainc_data, "abrainc"),
    format = "file"
  ),
  tar_target(
    name = abrainc_validation,
    command = validate_dataset(abrainc_data, "abrainc")
  ),

  # ---- SECOVI-SP - São Paulo Market Data ----
  tar_target(
    name = secovi_data,
    command = fetch_dataset("secovi"),
    cue = tar_cue_age(
      name = secovi_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = secovi_cache,
    command = save_to_cache(secovi_data, "secovi_sp"),
    format = "file"
  ),
  tar_target(
    name = secovi_validation,
    command = validate_dataset(secovi_data, "secovi")
  ),

  # ---- RPPI Sale - Residential Property Price Index (Sale) ----
  tar_target(
    name = rppi_sale_data,
    command = fetch_dataset("rppi", table = "sale"),
    cue = tar_cue_age(
      name = rppi_sale_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = rppi_sale_cache,
    command = save_to_cache(rppi_sale_data, "rppi_sale"),
    format = "file"
  ),
  tar_target(
    name = rppi_sale_validation,
    command = validate_dataset(rppi_sale_data, "rppi_sale")
  ),

  # ---- RPPI Rent - Residential Property Price Index (Rent) ----
  tar_target(
    name = rppi_rent_data,
    command = fetch_dataset("rppi", table = "rent"),
    cue = tar_cue_age(
      name = rppi_rent_data,
      age = as.difftime(7, units = "days")
    )
  ),
  tar_target(
    name = rppi_rent_cache,
    command = save_to_cache(rppi_rent_data, "rppi_rent"),
    format = "file"
  ),
  tar_target(
    name = rppi_rent_validation,
    command = validate_dataset(rppi_rent_data, "rppi_rent")
  ),

  # ========================================================================
  # MONTHLY UPDATES - Lower-priority datasets updated less frequently
  # ========================================================================

  # ---- BIS RPPI - International Property Price Data ----
  tar_target(
    name = bis_rppi_data,
    command = fetch_dataset("rppi_bis"),
    cue = tar_cue_age(
      name = bis_rppi_data,
      age = as.difftime(30, units = "days")
    )
  ),
  tar_target(
    name = bis_rppi_cache,
    command = save_to_cache(bis_rppi_data, "bis_selected"),
    format = "file"
  ),
  tar_target(
    name = bis_rppi_validation,
    command = validate_dataset(bis_rppi_data, "rppi_bis")
  ),

  # ---- CBIC - Construction Materials Data ----
  tar_target(
    name = cbic_data,
    command = fetch_dataset("cbic"),
    cue = tar_cue_age(
      name = cbic_data,
      age = as.difftime(30, units = "days")
    )
  ),
  tar_target(
    name = cbic_cache,
    command = save_to_cache(cbic_data, "cbic"),
    format = "file"
  ),
  tar_target(
    name = cbic_validation,
    command = validate_dataset(cbic_data, "cbic")
  ),

  # ---- Property Records - ITBI Transaction Data ----
  tar_target(
    name = property_records_data,
    command = fetch_dataset("property_records"),
    cue = tar_cue_age(
      name = property_records_data,
      age = as.difftime(14, units = "days")
    )
  ),
  tar_target(
    name = property_records_cache,
    command = save_to_cache(property_records_data, "property_records"),
    format = "file"
  ),
  tar_target(
    name = property_records_validation,
    command = validate_dataset(property_records_data, "property_records")
  ),

  # ---- NRE-IRE - Real Estate Index (cached only, manual update) ----
  # NOTE: NRE-IRE requires manual data processing (no download capability)
  # Uses source="github" to access cached data
  tar_target(
    name = nre_ire_data,
    command = fetch_dataset("nre_ire", source = "github"),
    cue = tar_cue(mode = "never")  # Manual update only
  ),
  tar_target(
    name = nre_ire_cache,
    command = save_to_cache(nre_ire_data, "nre_ire"),
    format = "file"
  ),
  tar_target(
    name = nre_ire_validation,
    command = validate_dataset(nre_ire_data, "nre_ire")
  ),

  # ========================================================================
  # PIPELINE SUMMARY
  # ========================================================================

  tar_target(
    name = pipeline_summary,
    command = {
      cli::cli_inform("Generating pipeline summary...")

      # Collect all cache files
      cache_files <- c(
        bcb_series_cache,
        bcb_realestate_cache,
        fgv_ibre_cache,
        abecip_cache,
        abrainc_cache,
        secovi_cache,
        rppi_sale_cache,
        rppi_rent_cache,
        bis_rppi_cache,
        cbic_cache,
        property_records_cache,
        nre_ire_cache
      )

      # Collect all validations
      validations <- list(
        bcb_series = bcb_series_validation,
        bcb_realestate = bcb_realestate_validation,
        fgv_ibre = fgv_ibre_validation,
        abecip = abecip_validation,
        abrainc = abrainc_validation,
        secovi = secovi_validation,
        rppi_sale = rppi_sale_validation,
        rppi_rent = rppi_rent_validation,
        bis_rppi = bis_rppi_validation,
        cbic = cbic_validation,
        property_records = property_records_validation,
        nre_ire = nre_ire_validation
      )

      summary_info <- list(
        timestamp = Sys.time(),
        datasets_updated = c(
          "bcb_series", "bcb_realestate", "fgv_ibre",
          "abecip", "abrainc", "secovi",
          "rppi_sale", "rppi_rent",
          "bis_rppi", "cbic", "property_records", "nre_ire"
        ),
        weekly_datasets = c(
          "bcb_series", "bcb_realestate", "fgv_ibre",
          "abecip", "abrainc", "secovi",
          "rppi_sale", "rppi_rent"
        ),
        monthly_datasets = c(
          "bis_rppi", "cbic", "property_records", "nre_ire"
        ),
        cache_files = cache_files,
        validations = validations
      )

      cli::cli_alert_success(
        "Pipeline completed: {length(summary_info$datasets_updated)} dataset(s) processed"
      )

      summary_info
    }
  )
)
