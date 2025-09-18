# Set up rb3 cache directory
fs::dir_create("data-raw/rb3")
options(rb3.cachedir = "data-raw/rb3")

library(rb3)
library(bizdays)
library(dplyr)
library(stringr)

stocks_category <- readxl::read_excel("data-raw/b3_real_estate.xlsx")

stocks_category <- stocks_category |>
  janitor::clean_names() |>
  mutate(
    ire = if_else(ire == "X", 1L, 0L),
    ire_bi = if_else(ire_bi == "X", 1L, 0L),
    imob = if_else(imob == "X", 1L, 0L)
  )

stock_category <- stocks_category |>
  rename(symbol = ticker) |>
  mutate(
    symbol = str_remove(symbol, "\\.SA?$"),
    is_residential = if_else(category == "Residential", 1L, 0L)
  ) |>
  select(symbol, name, name_short, category, is_residential)


# Fetch to download and store locally
fetch_marketdata(
  "b3-indexes-historical-data",
  index = c("^BVSP", "^IBX50", "EWZ", "EEM", "DBC", "IFIX"),
  year = 2023:2025,
  throttle = TRUE
)

# Then connect
indexes <- rb3::indexes_historical_data_get()

# Then collect
indexes |>
  dplyr::collect() |>
  # Rename columns to standard names
  rename(date = refdate)

# Fetch daily stock data

# Example for a short period

# Fetch data
fetch_marketdata(
  "b3-cotahist-daily",
  refdate = bizseq("2025-01-01", "2025-09-117", "Brazil/B3")
)

# Connect to local database
eq <- cotahist_get("daily")

# Extract residential stocks
stock_res <- eq |>
  dplyr::filter(symbol %in% stocks_category$) |>
  select(refdate, symbol, close, volume, trade_quantity, traded_contracts) |>
  collect()


# rascunho: replicar metodologia do NRE-IRE

estimate_ire <- function() {
  # For each day, get top 50% by volume and bottom 50% by volume
  total_day <- stock_res |>
    summarise(
      daily_vol = sum(volume, na.rm = TRUE),
      .by = "refdate"
    )

  stock_res |>
    left_join(total_day, by = "refdate") |>
    group_by(refdate) |>
    mutate(
      vol_pct = volume / daily_vol,
      rank_vol = rank(-volume, ties.method = "first")
    ) |>
    arrange(rank_vol) |>
    arrange(refdate) |>
    mutate(
      cum_vol = cumsum(vol_pct),
      flag_group = if_else(
        abs(cum_vol - 0.5) == min(abs(cum_vol - 0.5)),
        1L,
        0L
      ),
      vol_group = case_when(
        cum_vol < 0.5 ~ "top_50",
        flag_group == 1 ~ "top_50",
        TRUE ~ "bottom50"
      )
    ) |>
    ungroup() |>
    select(refdate, symbol, close, volume, vol_pct, vol_group)
}
