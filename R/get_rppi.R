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
    # Get IQA
    iqa <- get_rppi_iqa(cached)
    # Get IVAR
    ivar <- get_rppi_ivar(cached)
    # Standardize output
    ivar <- dplyr::select(ivar, date, name_muni, index, chg, acum12m)

    # Put all series in a named list
    rppi <- list(iqa, ivar, fipezap)
    names(rppi) <- c("IQA", "IVAR", "FipeZap")
  }

  if (category == "sale") {
    # Get IVGR
    ivgr <- suppressMessages(get_rppi_ivgr(cached))
    # Standardize output
    ivgr <- dplyr::rename(ivgr, name_muni = name_geo)
    # Get IGMI
    igmi <- get_rppi_igmi(cached)

    # Put all series in a named list
    rppi <- list(igmi, ivgr, fipezap)
    names(rppi) <- c("IGMI-R", "IVG-R", "FipeZap")
  }

  if (stack) {
    rppi <- dplyr::bind_rows(rppi, .id = "source")
  }

  return(rppi)

}

#' Get the IVGR Sales Index
#'
#' The IVGR Index is a monthly median sales index based on bank appraisals in
#' Brazil. The index is calculated by the Brazilian Central Bank.
#'
#' @details
#' The IVGR, or Residential Real Estate Collateral Value Index, is a monthly median
#' sales index based on bank appraisals in Brazil. Median property price indices
#' suffer from composition bias and cannot account for quality changes across the
#' housing stock.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` with the IVAR Index.
#' @export
#' @seealso [get_rppi()]
#'
#' @references Banco Central do Brasil (2018) "Índice de Valores de Garantia de Imóveis Residenciais Financiados (IVG-R). Seminário de Metodologia do IBGE."
#'
#' @examples
#' ivgr <- get_rppi_ivgr()
get_rppi_ivgr <- function(cached = FALSE) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Import data from BCB API
  ivgr <- GetBCBData::gbcbd_get_series(
    id = 21340,
    first.date = as.Date("2003-03-01")
  )

  # Clean data
  clean_ivgr <- ivgr |>
    # Rename columns and select only date and index
    dplyr::rename(date = ref.date, index = value) |>
    dplyr::select(date, index) |>
    dplyr::mutate(
      name_geo = "Brasil",
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12)
    )

  return(tidyr::as_tibble(clean_ivgr))

}

#' Get the IGMI Sales Index
#'
#' The IGMI Index is a monthly hedonic sales and is based on bank appraisal reports
#' in Brazil. The index is available for Brazil and 10 capital cities.
#'
#' @details
#' The IGMI, or Residential Real Estate Index, is a hedonic sales index based on
#' bank appraisal reports. Hedonic prices indices account for both composition
#' bias and quality differentials across the housing stock. The index is maintained
#' by Abecip in parternship with FGV.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble`
#' @examples
#' # get_abecip_igmi()
#'
get_rppi_igmi <- function(cached = FALSE) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
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

#' Get simplified RPPI data from BIS
#'
#' Download and import a simplified cross-country Residential Property Price
#' Indices (RPPI) panel data from the Bank for International Settlements (BIS).
#'
#' @details
#' This function is a wrapper around `get_bis_rppi_selected`. It simplifies the
#' output by filtering out observations prior to 1980. All index values are
#' centered in 2010. Both nominal and real series are available. Note that
#' Brazilian data becomes available only after 2001.
#'
#' The indexes follow the residential sales market in each country. Index
#' methodologies may not be comparable.
#'
#' @return A cross-country `tibble` with RPPIs.
#' @export
get_rppi_bis <- function(cached = FALSE) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  bis <- get_bis_rppi_selected()

  # Get only values from 1980 with non-NA values
  bis <- bis |>
    dplyr::filter(
      unit == "Index, 2010 = 100",
      date >= as.Date("1980-01-01"),
      !is.na(value)
    ) |>
    dplyr::select(
      date, code, country = reference_area, is_nominal, index = value
    )

  # Compute MoM and YoY percent changes by group
  bis <- bis |>
    dplyr::group_by(code) |>
    dplyr::mutate(
      chg = index / dplyr::lag(index) - 1,
      acum12m = RcppRoll::roll_prodr(1 + chg, n = 12)
    ) |>
    dplyr::ungroup()

  return(bis)

}

#' Get data from The QuintoAndar Rental Index (IQA)
#'
#' The QuintoAndar Rental Index is a monthly median stratified index calculated
#' for Brazil's two main cities: Rio de Janeiro and Sao Paulo. It takes into
#' account all new monthly rent contracts managed by QuintoAndar.
#'
#' @details
#' The IQA, or QuintoAndar Rental Index, is a median stratified index calculated
#' for Brazil's two main cities: Rio de Janeiro and Sao Paulo. Median property
#' price indices suffer from composition bias and cannot account for quality
#' changes across the housing stock. The source of the data are all the monthly
#' rent contracts managed by QuintoAndar. The Index includes only apartments and
#' similar units such as studios and flats.
#'
#' Despite the name "Index", the IQA provides a raw-price and not an index-number.
#' This means that the `rent_price` column is the median rent per square meter.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` with the most up to date QuintoAndar Rental Index.
#' @export
#' @seealso [get_rppi()]
#'
#' @examples
#' iqa <- get_rppi_iqa()
get_rppi_iqa <- function(cached = FALSE) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
  }

  # Import data
  url <- "https://publicfiles.data.quintoandar.com.br/Indice_QuintoAndar.csv"
  iqa <- readr::read_csv(url, col_types = "ccn")

  # Clean data
  clean_iqa <- iqa |>
    # Rename columns
    dplyr::select(
      date = mes,
      name_muni = cidade,
      rent_price = indice_quintoandar_precos_aluguel_reais_m2
    ) |>
    # Convert to appropriate types
    dplyr::mutate(
      # Parse dates from character to date
      date = readr::parse_date(date, format = "%Y-%m"),
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
#' The IVAR Index is a monthly repeat-rent index and is based on rental contracts
#' in four major Brazilian cities. The national index is calculated as a weighted
#' average of the four individual series.
#'
#' @details
#' The IVAR, or Residential Rent Variation Index, is a repeat-rent index, meaning
#' it compares the same housing unit across different points in time. The source
#' of the Index are rental contracts provided by brokers to IBRE (FGV).
#'
#' Although other price indices such as the IGP-M are commonly used in rental
#' contracts in Brazil, the IVAR is theoretically more appropriate since it
#' measures only rent prices.
#'
#' @inheritParams get_rppi
#'
#' @return A `tibble` stacking data for all cities. The national IVAR is defined
#' as the series with `name_muni = 'Brazil'`.
#' @export
#' @seealso [get_rppi()]
#' @examples
#' ivar <- get_rppi_ivar()
get_rppi_ivar <- function(cached = FALSE) {

  if (cached) {
    df <- readr::read_csv("...")
    return(df)
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

#' Get the FipeZap RPPI
#'
#' @details
#' The residential Index includes only apartments and
#' similar units such as studios and flats.
#'
#'
#' @param city Either the name of the city or `'all'` (default).
#' @inheritParams get_rppi
#'
#' @return A `tibble` with RPPI data for all selected cities
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

  if (cached) {
    df <- readr::read_csv("...")
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
