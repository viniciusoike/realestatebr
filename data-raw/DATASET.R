## code to prepare `DATASET` dataset goes here
library(dplyr)

# main_cities dataset removed in v0.4.0 - use dim_city instead

# Import city shapefile with official IBGE identifiers
dim_city <- geobr::read_municipality(year = 2020)
# Drop geometry
dim_city <- sf::st_drop_geometry(dim_city)
dim_city <- tibble::as_tibble(dim_city)
# Fix Espirito Santo state name

dim_city <- dim_city |>
  dplyr::mutate(
    name_state = dplyr::if_else(code_state == 32, "Espírito Santo", name_state)
  )

readr::write_csv(dim_city, "data-raw/dim_city.csv")

dim_city <- readr::read_csv("data-raw/dim_city.csv", show_col_types = FALSE)
# Convert code_state to numeric
dim_city <- dplyr::mutate(dim_city, code_state = as.numeric(code_state))

# Create a simplified name for cities
# Obs: can't use janitor::make_clean_names because of non-unique city names
dim_city <- dim_city |>
  dplyr::mutate(
    name_simplified = stringi::stri_trans_general(name_muni, "latin-ascii"),
    name_simplified = stringr::str_to_lower(name_simplified),
    name_simplified = stringr::str_replace_all(name_simplified, " ", "_")
  )

dim_state <- geobr::read_state(year = 2010)
dim_state <- sf::st_drop_geometry(dim_state)

dim_state <- dim_state |>
  dplyr::select(code_state, name_state) |>
  dplyr::mutate(
    name_state = stringr::str_replace(
      name_state,
      "Espirito Santo",
      "Esp\u00edrito Santo"
    )
  )

real_estate_symbols <- readxl::read_excel(
  "data-raw/b3_real_estate.xlsx",
  col_names = c(
    "symbol",
    "name",
    "name_short",
    "category",
    "segment",
    "mkt_value",
    "is_ire",
    "is_irebi",
    "is_imob"
  )
)

b3_real_estate <- real_estate_symbols |>
  select(symbol, name, name_short, category, segment)

usethis::use_data(dim_city, overwrite = TRUE)
usethis::use_data(b3_real_estate, overwrite = TRUE)
usethis::use_data(real_estate_symbols, internal = TRUE, overwrite = TRUE)
usethis::use_data(dim_state, internal = TRUE, overwrite = TRUE)

source("data-raw/abecip_cgi.R")
source("data-raw/fgv_clean.R")

ire <- readxl::read_excel(
  "data-raw/nre_ire.xlsx",
  skip = 1,
  col_types = c(
    "date",
    "numeric",
    "numeric",
    "numeric",
    "numeric",
    "numeric",
    "numeric",
    "numeric"
  ),
  col_names = c(
    "date",
    "ire",
    "ire_r50_plus",
    "ire_bi",
    "ire_r50_minus",
    "ibov",
    "ibov_points",
    "ire_ibov"
  )
)

ire <- dplyr::mutate(ire, date = lubridate::ymd(date))

usethis::use_data(abecip_cgi, internal = TRUE, overwrite = TRUE)
usethis::use_data(fgv_data, internal = TRUE, overwrite = TRUE)
usethis::use_data(ire, internal = TRUE, overwrite = TRUE)
