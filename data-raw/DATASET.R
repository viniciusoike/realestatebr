main_cities <- readr::read_rds("data-raw/main_cities.rds")

code_main_cities <- unique(main_cities$code_muni)

# Import city shapefile with official IBGE identifiers
# dim_city <- geobr::read_municipality(year = 2020)
# # Drop geometry
# dim_city <- sf::st_drop_geometry(dim_city)
# dim_city <- tibble::as_tibble(dim_city)
# readr::write_csv(dim_city, "data-raw/dim_city.csv")

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

b3_real_estate <- readxl::read_excel(
  "data-raw/b3_real_estate.xlsx",
  range = "A2:C39",
  col_names = c("symbol", "name", "name_short")
)

usethis::use_data(main_cities, overwrite = TRUE)
usethis::use_data(dim_city, overwrite = TRUE)
usethis::use_data(b3_real_estate, overwrite = TRUE)

source("data-raw/abecip_cgi.R")
source("data-raw/fgv_clean.R")

bcb_metadata <- readxl::read_excel("data-raw/bacen_codes.xlsx")


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

usethis::use_data(
  abecip_cgi,
  fgv_data,
  ire,
  bcb_metadata,
  internal = TRUE,
  overwrite = TRUE
)
