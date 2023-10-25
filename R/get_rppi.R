#' Get Residential Property Price Index Data
#'
#' Quickly import all Residential Price Indexes in Brazil. This function returns
#' a convenient standardized output.
#'
#' @details
#' There are several residential property price indexes in Brazil. This function
#' is a wrapper around all of the `get_rppi_*` functions that conveniently returns
#' a standardized output. The `index` column is the index-number, the `chg` column
#' is the percent change in the index number, and `acum12m` is the 12-month
#' accumulated variation in the index number.
#'
#' It's important to note the IQA Index is a raw price and not a index-number.
#'
#' @param category One of `'rent'` or `'sale'` (default).
#' @param cached If `TRUE` downloads the cached data from the GitHub repository.
#' This is a faster option but not recommended for daily data.
#' @param stack If `TRUE` returns a single `tibble` identified by a `source` column.
#' If `FALSE` returns a named `list` (default).
#'
#' @return Either a named `list` or a `tibble`.
#' @export
#'
#' @examples \dontrun{
#' # Get RPPI sales data
#' sales <- get_rppi("sale")
#'
#' # Get RPPI rent data
#' rent <- get_rppi("rent")
#'
#' }
get_rppi <- function(category = "sale", cached = FALSE, stack = FALSE) {

  # Import Index data from FipeZap
  fipezap <- get_rppi_fipezap(cached)

  # Standardize output
  fipezap <- fipezap |>
    # Select only the residential index and filter by operation
    dplyr::filter(
      market == "residential",
      rent_sale == category,
      variable %in% c("index", "chg", "acum12m"),
      rooms == "total"
    ) |>
    # Convert to wide
    tidyr::pivot_wider(
      id_cols = c("date", "name_muni"),
      names_from = "variable",
      values_from = "value"
    ) |>
    # Swap "Índice Fipezap+" for "Brazil"
    dplyr::mutate(
      name_muni = ifelse(name_muni == "Índice Fipezap+", "Brazil", name_muni)
    )

  if (category == "rent") {
    # Get Secovi-SP
    secovi <- get_rppi_secovi_sp(cached)
    # Get IQA
    iqa <- get_rppi_iqa(cached)
    # Get IVAR
    ivar <- get_rppi_ivar(cached)
    # Standardize output
    ivar <- dplyr::select(ivar, date, name_muni, index, chg, acum12m)

    # Put all series in a named list
    rppi <- list(iqa, ivar, secovi, fipezap)
    names(rppi) <- c("IQA", "IVAR", "Secovi-SP", "FipeZap")
  }

  if (category == "sale") {
    # Get IVGR
    ivgr <- suppressMessages(get_rppi_ivgr(cached))
    # Standardize output
    ivgr <- dplyr::mutate(ivgr, name_muni = "Brazil")
    ivgr <- dplyr::select(ivgr, -dplyr::any_of("name_geo"))
    # Get IGMI and standardize output
    igmi <- get_rppi_igmi(cached)
    igmi <- dplyr::mutate(igmi, name_muni = ifelse(name_muni == "Brasil", "Brazil", name_muni))
    # Put all series in a named list
    rppi <- list(igmi, ivgr, fipezap)
  }

  if (stack) {
    names(rppi) <- c("IGMI-R", "IVG-R", "FipeZap")
    rppi <- dplyr::bind_rows(rppi, .id = "source")
  } else {
    names(rppi) <- c("igmi_r", "ivg_r", "fipezap")
  }

  return(rppi)

}

#' Get the IVGR Sales Index
#'
#' Imports the IVG-R sales index
#'
#' @details
#' The IVG-R, or Residential Real Estate Collateral Value Index, is a monthly median
#' sales index based on bank appraisals in Brazil. The index is calculated by the
#' Brazilian Central Bank and is representative of the entire country. The index estimates
#' the long-run trend in home prices and encompasses Brazil's major metropolitan regions.
#' Trend in prices are obtained by the familiar Hodrick-Prescott filter (lambda = 3600)
#' applied to each city. The IVG-R is a weighted average of these price trends.
#'
#' Median property price indices suffer from composition bias and cannot account
#' for quality changes across the housing stock.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` with the IVAR Index where:
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' @export
#' @seealso [get_rppi()]
#'
#' @references Banco Central do Brasil (2018) "Índice de Valores de Garantia de Imóveis Residenciais Financiados (IVG-R). Seminário de Metodologia do IBGE."
#'
#' @examples
#' ivgr <- get_rppi_ivgr()
get_rppi_ivgr <- function(cached = FALSE) {

  if (cached) {
    ivgr <- import_cached("rppi_sale")
    ivgr <- dplyr::filter(ivgr, source == "IVG-R")
    return(ivgr)
  }

  # Import data from BCB API
  ivgr <- suppressMessages(
    GetBCBData::gbcbd_get_series(id = 21340, first.date = as.Date("2001-03-01"))
    )

  # Clean data
  clean_ivgr <- ivgr |>
    # Rename columns and select only date and index
    dplyr::rename(date = ref.date, index = value) |>
    dplyr::select(date, index) |>
    dplyr::mutate(
      name_geo = "Brazil",
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12) - 1
    )

  return(tidyr::as_tibble(clean_ivgr))

}

#' Get the IGMI Sales Index
#'
#' Imports the IGMI sales index for all cities available.
#'
#' @details
#' The IGMI-R, or Residential Real Estate Index, is a hedonic sales index based on
#' bank appraisal reports. The index is available for Brazil + 10 capital cities.
#'
#' Hedonic prices indices account for both composition bias and quality
#' differentials across the housing stock. The index is maintained by Abecip in
#' parternship with FGV.
#'
#' @inheritParams get_rppi
#' @export
#' @return A `tibble` stacking data for all cities. The national IGMI-R is defined
#' as the series with `name_muni == 'Brazil'`.
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' @examples
#' # get_abecip_igmi()
#'
get_rppi_igmi <- function(cached = FALSE) {

  if (cached) {
    igmi <- import_cached("rppi_sale")
    igmi <- dplyr::filter(igmi, source == "IGMI-R")
    return(igmi)
  }

  # Download data

  url <- "https://www.abecip.org.br/igmi-r-abecip/serie-historica"
  # Parse html into R
  parsed <- xml2::read_html(url)
  # Get the download link via xpath
  node <- rvest::html_element(parsed, xpath = "//div[@class='bloco_anexo']/a")
  url <- rvest::html_attr(node, "href")

  # Defines a default directory to output the data
  temp_path <- tempfile("igmi.xlsx")

  # Download the spreadsheet
  try(
    download.file(url, destfile = temp_path, mode = "wb", quiet = TRUE)
  )

  # Import data from spreadsheet
  igmi <- readxl::read_excel(
    path = temp_path,
    skip = 4,
    # Use janitor to name repair the columns
    .name_repair = janitor::make_clean_names)

  # Auxiliar data.frame to vlookup city names
  dim_geo <- data.frame(
    name_muni = c(
      "Belo Horizonte", "Brasil", "Brasília", "Curitiba", "Fortaleza", "Goiânia",
      "Porto Alegre", "Recife", "Rio De Janeiro", "Salvador", "São Paulo"),
    name_simplified = c(
      "belo_horizonte", "brasil", "brasilia", "curitiba", "fortaleza", "goiania",
      "porto_alegre", "recife", "rio_de_janeiro", "salvador", "sao_paulo")
  )

  # Clean the data
  clean_igmi <- igmi |>
    # Rename date column
    dplyr::rename(date = mes) |>
    # Parse date to Date format
    dplyr::mutate(date = suppressWarnings(readr::parse_date(date, format = "%Y %m"))) |>
    # Remove all NAs in date column
    dplyr::filter(!is.na(date)) |>
    # Drop last column (12-month brazil)
    dplyr::select(-var_percent_12_meses)

  clean_igmi <- clean_igmi |>
    # Convert data to long (previous column names are now 'name_simplified')
    tidyr::pivot_longer(
      cols = -date,
      names_to = "name_simplified",
      values_to = "index") |>
    # Compute MoM and YoY change
    dplyr::group_by(name_simplified) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12) - 1) |>
    dplyr::ungroup() |>
    dplyr::left_join(dim_geo, by = "name_simplified") |>
    # Select column order
    dplyr::select(date, name_muni, index, chg, acum12m)

  return(clean_igmi)

}

#' Get data from The QuintoAndar Rental Index (IQA)
#'
#' Imports the QuintoAndar Rental Index for all cities available.
#'
#' @details
#' The IQA, or QuintoAndar Rental Index, is a median stratified index calculated
#' for Brazil's two main cities: Rio de Janeiro and São Paulo. The source of the
#' data are all the new rent contracts managed by QuintoAndar. The Index includes
#' only apartments and similar units such as studios and flats.
#'
#' Despite the name "Index", the IQA actually provides a raw-price and not an index-number.
#' This means that the `rent_price` column is the median rent per square meter.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` QuintoAndar Rental Index where
#'
#' * `rent_price` is the median rent price per squared meter.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' @export
#' @seealso [get_rppi()]
#'
#' @examples
#' # Get the IQA index
#' iqa <- get_rppi_iqa()
#'
#' # Subset Rio de Janeiro
#' rio <- subset(iqa, name_muni == "Rio de Janeiro")
get_rppi_iqa <- function(cached = FALSE) {

  if (cached) {
    iqa <- import_cached("rppi_rent")
    iqa <- dplyr::filter(iqa, source == "IQA")
    return(iqa)
  }

  # Import data
  url <- "https://publicfiles.data.quintoandar.com.br/Indice_QuintoAndar.csv"
  iqa <- readr::read_csv(url, col_types = "cDn")

  # Clean data
  clean_iqa <- iqa |>
    # Rename columns
    dplyr::select(
      date = month,
      name_muni = city_name,
      rent_price = weighted_median_contract_rent_per_sqm
    ) |>
    # Convert to appropriate types
    dplyr::mutate(
      # Capitalize strings
      name_muni = stringr::str_to_title(name_muni, locale = "pt_BR"),
      # Convert rent price to numeric
      rent_price = as.numeric(rent_price)
    )

  # Calculate MoM change in index and 12-month change
  clean_iqa <- clean_iqa |>
    dplyr::group_by(name_muni) |>
    dplyr::mutate(
      chg = rent_price / dplyr::lag(rent_price) - 1,
      acum12m = rent_price / dplyr::lag(rent_price, n = 12) - 1
    ) |>
    dplyr::ungroup()

  return(clean_iqa)

}

#' Get the IVAR rent Index
#'
#' Imports the IVAR rent index for all cities available.
#'
#' @details
#' The IVAR, or Residential Rent Variation Index, is a repeat-rent index, meaning
#' it compares the same housing unit across different points in time. The source
#' of the Index are rental contracts provided by brokers to IBRE (FGV). Data is available
#' in four major Brazilian cities; the national index is calculated as a weighted
#' average of the four individual series.
#'
#' Although other price indices such as the IGP-M are commonly used in rental
#' contracts in Brazil, the IVAR is theoretically more appropriate since it
#' measures only rent prices.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` stacking data for all cities. The national IVAR is defined
#' as the series with `name_muni == 'Brazil'`.
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
#'
#' @export
#' @seealso [get_rppi()]
#' @examples
#' # Get the IVAR index
#' ivar <- get_rppi_ivar()
#'
#' # Subset national index
#' brasil <- subset(ivar, name_muni == "Brazil")
get_rppi_ivar <- function(cached = FALSE) {

  if (cached) {
    ivar <- import_cached("rppi_rent")
    ivar <- dplyr::filter(ivar, source = "IVAR")
  }

  ivar_cities <- dim_city |>
    dplyr::filter(
      code_muni %in% c(3550308, 4314902, 3304557, 3106200)
    ) |>
    dplyr::select(name_simplified, name_muni, abbrev_state)

  # Filter IVAR from fgv_data, select columns and change the value column name
  ivar <- fgv_data |>
    dplyr::filter(stringr::str_detect(name_simplified, "^ivar")) |>
    dplyr::select(date, name_simplified, index = value) |>
    dplyr::filter(!is.na(index))

  # Group by city and compute percent change and YoY change
  ivar <- ivar |>
    dplyr::group_by(name_simplified) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12)
    ) |>
    dplyr::ungroup()

  # Join with proper city names and select column order
  ivar <- ivar |>
    dplyr::mutate(
      name_simplified = stringr::str_remove(name_simplified, "ivar_")
    ) |>
    dplyr::left_join(ivar_cities, by = "name_simplified") |>
    dplyr::mutate(
      name_muni = ifelse(name_simplified == "brazil", "Brazil", name_muni),
      abbrev_state = ifelse(name_simplified == "brazil", "BR", abbrev_state)
    ) |>
    dplyr::select(
      date, name_muni, index, chg, acum12m, name_simplified, abbrev_state
      )

  return(ivar)

}

#' Get the Secovi-SP Rent Index
#'
#' Imports the Secovi-SP rent index for São Paulo.
#'
#' @inheritParams get_rppi
#' @export
#' @return A `tibble` with the Secovi Rent Index where:
#'
#' * `index` is the index-number.
#' * `chg` is the monthly change.
#' * `acum12m` is the year-on-year change.
get_rppi_secovi_sp <- function(cached = FALSE) {

  if (cached) {
    secovi <- import_cached("rppi_rent")
    secovi <- dplyr::filter(secovi, source = "Secovi-SP")
  }

  secovi <- get_secovi("rent", cached = FALSE)

  secovi_index <- secovi |>
    dplyr::filter(category == "rent", variable == "rent_price") |>
    dplyr::rename(index = value) |>
    dplyr::mutate(
      name_muni = "São Paulo",
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12) - 1
    ) |>
    dplyr::select(date, name_muni, index, chg, acum12m)

  return(secovi_index)

}

#' Get the FipeZap RPPI
#'
#' Import residential and commercial prices indices from FipeZap
#'
#' @details
#' The FipeZap Index is a monthly median stratified index calculated across several
#' cities in Brazil. This function imports both the rental and the sale index for
#' all cities. The Index is based on online listings of the Zap Imóveis group and is
#' stratified by number of rooms. The overall city index is a weighted sum of median
#' prices by room/region.
#'
#' The residential Index includes only apartments and similar units such as studios and flats.
#'
#' Choosing a specific city will only filter the final results and will not save
#' processing/downloading time.
#'
#' @param city Either the name of the city or `'all'` (default). If the chosen
#' city name is not available the full table will be returned.
#' @inheritParams get_rppi
#'
#' @return A `tibble` with RPPI data for all selected cities where:
#'
#' * `market` - specifices either `'commercial'` or `'residential'`
#' * `rent_sale` - specifies either `'rent'` or `'sale'`
#' * `variable` - 'index' is the index-number, 'chg' is the monthly change, 'acum12m' is the year-on-year change, 'price_m2' is the raw sale/rent price per squared meter, and 'yield' is the gross rental yield.
#' * `rooms` - number of rooms (`total` is the average)
#'
#' The national index is defined as the series with `name_muni == 'Índice Fipezap+'`.
#'
#' @export
#' @seealso [get_rppi()]
#' @examples \dontrun{ if (interactive) {
#'
#' # Get all the available indices
#' # fz <- get_rppi_fipezap()
#'
#' # Get all indices available for Porto Alegre
#' # poa <- get_rppi_fipezap(city = "Porto Alegre")
#'
#' }}
#'
get_rppi_fipezap <- function(city = "all", cached = FALSE) {

  # Download cached data from the GitHub repository
  if (cached) {
    df <- import_cached("rppi_fipe")

    if (city != "all" && city %in% unique(df$name_muni)) {
      df <- dplyr::filter(df, name_muni == city)
    }

    return(df)
  }

  url <- "https://downloads.fipe.org.br/indices/fipezap/fipezap-serieshistoricas.xlsx"
  temp_path <- tempfile("fipezap.xlsx")
  httr::GET(url = url, httr::write_disk(path = temp_path, overwrite = TRUE))

  # Get all unique sheet names
  sheet_names <- readxl::excel_sheets(temp_path)
  # Remove summary sheets
  sheet_names <- sheet_names[!stringr::str_detect(sheet_names, "(Resumo)|(Aux)")]
  # Use sheets as city names
  city_names <- stringr::str_to_title(sheet_names)

  # Import all data

  import_fipezap <- \(x) {

    # Get import range
    range <- get_range(path = temp_path, sheet = x)

    # Ad-hoc fix for get_range
    if (!stringr::str_detect(range, "BD")) {
      max_col <- stringr::str_extract(
        stringr::str_match(range, ":[A-Z]+[0-9]"),
        "[A-Z]+")
      n1 <- stringr::str_locate(range, max_col)[, 1]
      n2 <- stringr::str_locate(range, max_col)[, 2]
      range <- paste0(
        stringr::str_sub(range, 1, n1 - 1),
        "BD",
        stringr::str_sub(range, n2 + 1, nchar(range)))
    }

    # Import Excel
    fipe <- readxl::read_excel(
      temp_path,
      sheet = x,
      skip = 4,
      col_names = fipezap_col_names(),
      range = range
    )
    # Converts all character columns to numeric
    fipe <- fipe |>
      dplyr::mutate(dplyr::across(dplyr::where(is.character), as.numeric))

    return(fipe)

  }

  # Import data from all sheets
  fipezap <- parallel::mclapply(sheet_names, import_fipezap)
  # Names each list element using city names
  names(fipezap) <- city_names
  # Stacks all sheets together
  fipezap <- dplyr::bind_rows(fipezap, .id = "name_muni")

  # Clean data

  clean_fipe <- fipezap |>
    # Convert from wide to long
    tidyr::pivot_longer(
      cols = dplyr::where(is.numeric),
      names_to = "info",
      values_to = "value"
    ) |>
    # Split the info column to facilitate row-filtering
    tidyr::separate_wider_delim(
      cols = "info",
      names = c("market", "rent_sale", "variable", "rooms"),
      delim = "-"
    ) |>
    # Convert the date column to YMD
    dplyr::mutate(date = lubridate::ymd(date)) |>
    # Select column order
    dplyr::select(date, name_muni, market, rent_sale, variable, rooms, value)

  if (city != "all" && city %in% unique(clean_fipe$name_muni)) {

    clean_fipe <- dplyr::filter(clean_fipe, name_muni == city)

  }

  return(clean_fipe)

}

#' Creates column names for the FipeZap spreadsheet
#'
#' @details Since all tables follow the column-name strucure, this function serves
#' as an easy wrapper to avoid import issues. Should always be used with
#' readxl::read_excel(col_names = FALSE).
#' Categories are: residential x commercial, sales x rent, and number of rooms.
#' Variables include:
#' FipeIndex (index), month on month change (chg), 12 months accumulated change (chg_12m),
#' and price/rent per squared meter (price_m2).
#' Total rooms represents a weighted average of 1, 2, 3, and 4 bedrooms indicies.
#' @noRd
fipezap_col_names <- function() {

  market <- c("residential", "commercial")
  transaction <- c("sale", "rent")
  var_sale <- c("index", "chg", "acum12m", "price_m2")
  var_rent <- c(var_sale, "yield")
  rooms <- c("total", 1:4)

  cols_sale <- paste(rep(var_sale, each = length(rooms)), rooms, sep = "-")
  cols_rent <- paste(rep(var_rent, each = length(rooms)), rooms, sep = "-")

  cols_res <- c(
    paste(market[1], transaction[1], cols_sale, sep = "-"),
    paste(market[1], transaction[2], cols_rent, sep = "-")
  )

  cols_com <- c(
    paste(market[2], transaction[1], var_sale, "total", sep = "-"),
    paste(market[2], transaction[2], var_rent, "total", sep = "-")
  )

  cols_full <- c(cols_res, cols_com)
  out <- c("date", cols_full)

  return(out)
}
