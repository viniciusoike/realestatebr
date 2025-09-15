# data-raw/update_data.R
# Updated data update script using new unified architecture
# Load required packages
library(realestatebr)
library(here)
library(vroom)
library(readr)
library(cli)

# Create log directory
log_dir <- here("logs")
dir.create(log_dir, showWarnings = FALSE)
log_file <- file.path(log_dir, format(Sys.time(), "update_log_%Y%m%d.txt"))

# Logging function
log_message <- function(msg) {
  timestamp <- format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
  full_msg <- paste(timestamp, msg)
  message(full_msg)
  cat(full_msg, "\n", file = log_file, append = TRUE)
}

# Function to safely execute data retrieval
safe_get_data <- function(fn, ...) {
  tryCatch(
    {
      result <- fn(...)
      log_message(sprintf("Successfully retrieved data from %s", deparse(substitute(fn))))
      result
    },
    error = function(e) {
      log_message(sprintf("Error in %s: %s", deparse(substitute(fn)), e$message))
      NULL
    }
  )
}

# Function to safely write data
safe_write_data <- function(data, filename, write_fn = vroom_write, ...) {
  if (is.null(data)) {
    log_message(sprintf("Skipping write for %s - no data available", filename))
    return(FALSE)
  }

  tryCatch(
    {
      write_fn(data, here("cached_data", filename), ...)
      log_message(sprintf("Successfully wrote %s", filename))
      TRUE
    },
    error = function(e) {
      log_message(sprintf("Error writing %s: %s", filename, e$message))
      FALSE
    }
  )
}

# Get list of all available datasets using new unified architecture
log_message("Starting data update process using unified architecture")

available_datasets <- list_datasets()
log_message(sprintf("Found %d datasets to update", nrow(available_datasets)))

# Function to get data using new unified interface
safe_get_unified_data <- function(dataset_name, category = NULL) {
  tryCatch({
    cli_alert_info("Fetching {dataset_name}{if(!is.null(category)) paste0(' (', category, ')')}")
    
    # Force fresh download for cache updates
    data <- get_dataset(dataset_name, source = "fresh", category = category)
    
    log_message(sprintf("Successfully retrieved %s%s", 
                       dataset_name, 
                       if(!is.null(category)) paste0(" (", category, ")") else ""))
    
    return(data)
  }, error = function(e) {
    cli_alert_danger("Failed to fetch {dataset_name}: {e$message}")
    log_message(sprintf("Error retrieving %s: %s", dataset_name, e$message))
    return(NULL)
  })
}

# Retrieve all priority datasets using new architecture
data_list <- list()

# Single datasets (tibbles)
single_datasets <- list(
  bcb_realestate = "bcb_realestate",
  bcb_series = "bcb_series", 
  b3_stocks = "b3_stocks",
  secovi_sp = "secovi",
  bis_selected = "bis_rppi",
  fgv_indicators = "fgv_indicators"
)

for(name in names(single_datasets)) {
  data_list[[name]] <- safe_get_unified_data(single_datasets[[name]])
}

# Special handling for BIS detailed (different category)
data_list[["bis_detailed"]] <- safe_get_unified_data("bis_rppi", "detailed")

# Multi-category datasets (lists)
data_list[["abrainc"]] <- safe_get_unified_data("abrainc_indicators")
data_list[["abecip"]] <- safe_get_unified_data("abecip_indicators")

# RPPI datasets
data_list[["rppi_sale"]] <- safe_get_unified_data("rppi", "sale")
data_list[["rppi_rent"]] <- safe_get_unified_data("rppi", "rent") 
data_list[["rppi_fipe"]] <- safe_get_unified_data("rppi", "fipe")

# Legacy datasets that may not be in unified architecture yet
data_list[["prop_records"]] <- safe_get_data(get_property_records, "all")

# Write CSV files
csv_files <- list(
  bcb_series = "bcb_series.csv.gz",
  bcb_realestate = "bcb_realestate.csv.gz",
  b3_stocks = "b3_stocks.csv.gz",
  rppi_sale = "rppi_sale.csv.gz",
  rppi_rent = "rppi_rent.csv.gz",
  secovi_sp = "secovi_sp.csv.gz",
  bis_selected = "bis_selected.csv.gz",
  rppi_fipe = "rppi_fipe.csv.gz"
)

for (name in names(csv_files)) {
  safe_write_data(data_list[[name]], csv_files[[name]])
}

# Write RDS files
rds_files <- list(
  abrainc = "abrainc.rds",
  abecip = "abecip.rds",
  prop_records = "property_records.rds",
  bis_detailed = "bis_detailed.rds"
)

for (name in names(rds_files)) {
  safe_write_data(data_list[[name]], rds_files[[name]],
                  write_fn = write_rds, compress = "gz")
}

log_message("Data update process completed")
