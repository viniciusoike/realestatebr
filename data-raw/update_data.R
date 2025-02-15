# data-raw/update_data.R

# Load required packages
library(realestatebr)
library(here)
import::from(vroom, vroom_write)
import::from(readr, write_rds)

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

# Retrieve all data
log_message("Starting data update process")

data_list <- list(
  bcb_realestate = safe_get_data(get_bcb_realestate, "all"),
  bcb_series = safe_get_data(get_bcb_series, "all"),
  b3_stocks = safe_get_data(get_b3_stocks),
  abrainc = safe_get_data(get_abrainc_indicators, "all"),
  abecip = safe_get_data(get_abecip_indicators, "all"),
  prop_records = safe_get_data(get_property_records, "all"),
  secovi_sp = safe_get_data(get_secovi, "all"),
  rppi_sale = safe_get_data(get_rppi, "sale", stack = TRUE),
  rppi_rent = safe_get_data(get_rppi, "rent", stack = TRUE),
  bis_selected = safe_get_data(get_bis_rppi, "selected"),
  bis_detailed = safe_get_data(get_bis_rppi, "detailed"),
  rppi_fipe = safe_get_data(get_rppi_fipezap, city = "all")
)

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
