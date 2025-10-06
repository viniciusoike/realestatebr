# Process NRE-IRE Data and Create Cache File
# This script reads the source Excel file and creates the cached RDS file

library(readxl)
library(dplyr)
library(lubridate)

# Read the Excel file
ire_raw <- readxl::read_excel(
  "data-raw/nre_ire.xlsx",
  sheet = 1,
  skip = 2  # Skip header rows
)

# Clean and process the data
ire <- ire_raw %>%
  rename(
    date = 1,
    ire = 2,
    ire_r50_plus = 3,
    ire_r50_minus = 4,
    ire_bi = 5,
    ibov = 6,
    ibov_points = 7,
    ire_ibov = 8
  ) %>%
  mutate(
    # Ensure date is proper date format
    date = as.Date(date)
  ) %>%
  filter(!is.na(date))  # Remove any rows without dates

# Add metadata
attr(ire, "source") <- "NRE-Poli-USP"
attr(ire, "generated") <- Sys.time()
attr(ire, "note") <- "Real Estate Index - Base 100 = May 2006"

# Save to cache
saveRDS(ire, "inst/cached_data/nre_ire.rds", compress = TRUE)

cat("✓ Created nre_ire.rds cache file\n")
cat("  Rows:", nrow(ire), "\n")
cat("  Date range:", min(ire$date), "to", max(ire$date), "\n")
