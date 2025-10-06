#' Standardize City Names Across RPPI Sources
#'
#' @param names Character vector of city names
#' @return Standardized city names
#' @keywords internal
#' @noRd
standardize_city_names <- function(names) {
  standardized_names <- names |>
    # Standardize Brazil variations
    stringr::str_replace("Brasil", "Brazil") |>
    # Fix: Case-insensitive match for "Índice FipeZap" with optional "+"
    stringr::str_replace("(?i)\u00cdndice\\s+FipeZap\\+?", "Brazil") |>
    # Other standardizations can be added here
    trimws()

  return(standardized_names)
}

#' Harmonize FipeZap Data for Stacking
#'
#' @param dat FipeZap data tibble
#' @param transaction_type "sale" or "rent" to filter for stacking
#' @return Harmonized tibble with standard RPPI columns
#' @keywords internal
harmonize_fipezap_for_stacking <- function(dat, transaction_type = NULL) {
  filtered_data <- dat |>
    # Filter to residential data with total rooms only
    dplyr::filter(
      market == "residential",
      rooms == "total",
      variable %in% c("index", "chg", "acum12m")
    )

  # Filter by transaction type if specified
  if (!is.null(transaction_type)) {
    filtered_data <- filtered_data |>
      dplyr::filter(rent_sale == transaction_type)
  }

  # Convert to wide format with standard columns
  harmonized_data <- filtered_data |>
    tidyr::pivot_wider(
      id_cols = c("date", "name_muni"),
      names_from = "variable",
      values_from = "value"
    ) |>
    dplyr::mutate(
      name_muni = standardize_city_names(name_muni)
    ) |>
    dplyr::select(date, name_muni, index, chg, acum12m)

  return(harmonized_data)
}

#' Standardize RPPI Structure
#'
#' @param dat Input tibble from any RPPI source
#' @param source_name Name to add as source column
#' @return Standardized tibble with consistent columns
#' @keywords internal
standardize_rppi_structure <- function(dat, source_name) {
  # Handle IQA special case (has rent_price instead of index)
  if ("rent_price" %in% names(dat) && !"index" %in% names(dat)) {
    dat <- dat |>
      dplyr::rename(index = rent_price)
  }

  # Handle different column name variations
  if ("name_geo" %in% names(dat) && !"name_muni" %in% names(dat)) {
    dat <- dat |>
      dplyr::rename(name_muni = name_geo)
  }

  # Ensure standard columns exist and are in correct order
  standardized_data <- dat |>
    dplyr::mutate(
      name_muni = standardize_city_names(name_muni)
    ) |>
    dplyr::select(date, name_muni, index, chg, acum12m) |>
    dplyr::mutate(source = source_name)

  return(standardized_data)
}


#' Get Stacked RPPI Data
#'
#' @details
#' Stacks multiple Brazilian residential property price indices into a single tibble
#' with consistent columns for easy comparison. Handles different RPPI sources (IGMI-R,
#' IVG-R, FipeZap, IVAR, IQA, Secovi-SP) and standardizes their formats.
#'
#' Note: IQA provides raw prices, not index numbers. Use get_dataset("rppi", table)
#' for individual indices.
#'
#' @param table Character. "sale", "rent", or "all"
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses messages
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, source
#'  (plus transaction_type if table="all")
#'
#' @keywords internal
get_rppi <- function(
  table = "sale",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Validate table
  valid_tables <- c("sale", "rent", "all")
  if (!table %in% valid_tables) {
    cli::cli_abort(
      "Invalid table: {.val {table}}. Valid: {.val {valid_tables}}"
    )
  }

  # Stack sale indices
  if (table == "sale") {
    igmi <- get_rppi_igmi(cached, quiet, max_retries)
    ivgr <- get_rppi_ivgr(cached, quiet, max_retries)
    fipezap <- get_rppi_fipezap(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )

    stacked_data <- dplyr::bind_rows(
      standardize_rppi_structure(igmi, "IGMI-R"),
      standardize_rppi_structure(ivgr, "IVG-R"),
      harmonize_fipezap_for_stacking(fipezap, "sale") |>
        dplyr::mutate(source = "FipeZap")
    )
  } else if (table == "rent") {
    # Stack rent indices
    ivar <- get_rppi_ivar(cached, quiet, max_retries)
    iqa <- get_rppi_iqa(cached, quiet, max_retries)
    secovi <- get_rppi_secovi_sp(cached, quiet, max_retries)
    fipezap <- get_rppi_fipezap(
      cached = cached,
      quiet = quiet,
      max_retries = max_retries
    )

    stacked_data <- dplyr::bind_rows(
      standardize_rppi_structure(ivar, "IVAR"),
      standardize_rppi_structure(iqa, "IQA"),
      standardize_rppi_structure(secovi, "Secovi-SP"),
      harmonize_fipezap_for_stacking(fipezap, "rent") |>
        dplyr::mutate(source = "FipeZap")
    )
  } else {
    # Stack all (both sale and rent)
    rent_data <- get_rppi("rent", cached, quiet, max_retries)
    sale_data <- get_rppi("sale", cached, quiet, max_retries)

    stacked_data <- dplyr::bind_rows(
      dplyr::mutate(rent_data, transaction_type = "rent"),
      dplyr::mutate(sale_data, transaction_type = "sale")
    )
  }

  if (!quiet) {
    cli::cli_inform(
      "✓ RPPI ({table}): {nrow(stacked_data)} records from {length(unique(stacked_data$source))} sources"
    )
  }

  stacked_data
}

#' Get the IVGR Sales Index
#'
#' @details
#' The IVG-R (Residential Real Estate Collateral Value Index) is a monthly median
#' sales index based on bank appraisals, calculated by the Brazilian Central Bank
#' (BCB series 21340). The index estimates long-run trends in home prices using the
#' Hodrick-Prescott filter (lambda=3600) applied to major metropolitan regions.
#' Note: Median indices suffer from composition bias and cannot account for quality
#' changes across the housing stock.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_geo, index, chg, acum12m
#'
#' @references Banco Central do Brasil (2018) "Indice de Valores de Garantia de
#' Imoveis Residenciais Financiados (IVG-R). Seminario de Metodologia do IBGE."
#'
#' @keywords internal
get_rppi_ivgr <- function(cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Try cached first
  if (cached) {
    data <- try_rppi_cached("sale", "IVG-R")
    if (!is.null(data)) return(data)
  }

  # Download fresh from BCB
  ivgr <- download_with_retry(
    function() {
      rbcb::get_series(21340, start_date = as.Date("2001-03-01")) |>
        dplyr::rename(index = 2)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "IVGR data from BCB"
  )

  # Clean and calculate changes
  ivgr |>
    dplyr::mutate(name_geo = "Brazil") |>
    dplyr::select(date, name_geo, index) |>
    calculate_rppi_changes(index_col = "index")
}

#' Get the IGMI Sales Index
#'
#' @details
#' The IGMI-R (Residential Real Estate Index) is a hedonic sales index based on
#' bank appraisal reports, available for Brazil + 10 capital cities. Hedonic indices
#' account for both composition bias and quality differentials across the housing stock.
#' Maintained by ABECIP in partnership with FGV.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m
#'
#' @keywords internal
get_rppi_igmi <- function(cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Try cached first
  if (cached) {
    data <- try_rppi_cached("sale", "IGMI-R")
    if (!is.null(data)) return(data)
  }

  # Scrape download URL and download Excel with retry
  temp_path <- download_with_retry(
    function() {
      base_url <- "https://www.abecip.org.br/igmi-r-abecip/serie-historica"
      parsed <- xml2::read_html(base_url)
      node <- rvest::html_element(
        parsed,
        xpath = "//div[@class='bloco_anexo']/a"
      )
      download_url <- rvest::html_attr(node, "href")

      if (is.na(download_url)) {
        stop("Could not find Excel download link on ABECIP website")
      }

      temp_path <- tempfile(fileext = ".xlsx")
      utils::download.file(download_url, temp_path, mode = "wb", quiet = TRUE)

      if (!file.exists(temp_path) || file.size(temp_path) == 0) {
        stop("Downloaded file is empty")
      }

      temp_path
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "IGMI Excel from ABECIP"
  )

  # City name mapping
  dim_geo <- data.frame(
    name_muni = c(
      "Belo Horizonte",
      "Brasil",
      "Bras\u00edlia",
      "Curitiba",
      "Fortaleza",
      "Goi\u00e2nia",
      "Porto Alegre",
      "Recife",
      "Rio De Janeiro",
      "Salvador",
      "S\u00e3o Paulo"
    ),
    name_simplified = c(
      "belo_horizonte",
      "brasil",
      "brasilia",
      "curitiba",
      "fortaleza",
      "goiania",
      "porto_alegre",
      "recife",
      "rio_de_janeiro",
      "salvador",
      "sao_paulo"
    )
  )

  # Process Excel
  readxl::read_excel(
    temp_path,
    skip = 4,
    .name_repair = janitor::make_clean_names
  ) |>
    dplyr::rename(date = mes) |>
    dplyr::mutate(
      date = suppressWarnings(readr::parse_date(date, format = "%Y %m"))
    ) |>
    dplyr::filter(!is.na(date)) |>
    dplyr::select(-var_percent_12_meses) |>
    tidyr::pivot_longer(
      cols = -date,
      names_to = "name_simplified",
      values_to = "index"
    ) |>
    calculate_rppi_changes(
      index_col = "index",
      group_col = "name_simplified"
    ) |>
    dplyr::left_join(dim_geo, by = "name_simplified") |>
    dplyr::select(date, name_muni, index, chg, acum12m)
}

#' Get QuintoAndar Rental Index (IQA)
#'
#' @details
#' The IQA (QuintoAndar Rental Index) is a median stratified index for Rio de Janeiro
#' and São Paulo, based on new rent contracts managed by QuintoAndar. Includes only
#' apartments, studios, and flats. Note: IQA provides raw prices (not index numbers),
#' so `rent_price` is the median rent per square meter.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, rent_price, chg, acum12m
#'
#' @keywords internal
get_rppi_iqa <- function(cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Try cached first
  if (cached) {
    data <- try_rppi_cached("rent", "IQA")
    if (!is.null(data)) return(data)
  }

  # Download CSV with retry
  url <- "https://publicfiles.data.quintoandar.com.br/Indice_QuintoAndar.csv"
  iqa <- download_with_retry(
    function() readr::read_csv(url, col_types = "cDn", show_col_types = FALSE),
    max_retries = max_retries,
    quiet = quiet,
    desc = "IQA CSV from QuintoAndar"
  )

  # Clean and calculate changes
  iqa |>
    dplyr::select(
      date = month,
      name_muni = city_name,
      rent_price = weighted_median_contract_rent_per_sqm
    ) |>
    dplyr::mutate(
      name_muni = stringr::str_to_title(name_muni, locale = "pt_BR"),
      rent_price = as.numeric(rent_price)
    ) |>
    dplyr::mutate(
      chg = rent_price / dplyr::lag(rent_price) - 1,
      acum12m = rent_price / dplyr::lag(rent_price, n = 12) - 1,
      .by = name_muni
    )
}

#' Get IVAR Rent Index
#'
#' @details
#' The IVAR (Residential Rent Variation Index) is a repeat-rent index from IBRE/FGV,
#' comparing the same housing unit over time. Based on rental contracts from brokers.
#' Available for 4 major cities (São Paulo, Rio, Porto Alegre, Belo Horizonte); the
#' national index is a weighted average. More theoretically sound than IGP-M for rent
#' contracts as it measures only rent prices.
#'
#' @note IVAR data is only available from cache as the source data (FGV) is not
#' accessible via web scraping. This function will automatically use cached data
#' when source data is unavailable.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache (recommended)
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts (not used for this data source)
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, name_simplified, abbrev_state
#'
#' @keywords internal
get_rppi_ivar <- function(cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Try cached first
  if (cached) {
    data <- try_rppi_cached("rent", "IVAR")
    if (!is.null(data)) return(data)
  }

  # Check for required package data - if not available, force cache
  if (!exists("fgv_data") || !exists("dim_city")) {
    if (!quiet) {
      cli::cli_inform(c(
        "i" = "IVAR source data not available, loading from cache..."
      ))
    }

    # Force load from cache
    data <- tryCatch(
      {
        import_cached("rppi_ivar", quiet = quiet)
      },
      error = function(e) {
        cli::cli_abort(c(
          "IVAR data not available",
          "x" = "Source data (fgv_data) is not accessible and cache is unavailable",
          "i" = "IVAR requires static FGV data that is not web-scrapable",
          "i" = "Please use cached data: get_dataset('rppi', 'ivar', source = 'github')"
        ))
      }
    )

    return(data)
  }

  # City mapping for IVAR cities
  ivar_cities <- dim_city |>
    dplyr::filter(code_muni %in% c(3550308, 4314902, 3304557, 3106200)) |>
    dplyr::select(name_simplified, name_muni, abbrev_state)

  # Extract and process IVAR data
  fgv_data |>
    dplyr::filter(stringr::str_detect(name_simplified, "^ivar")) |>
    dplyr::select(date, name_simplified, index = value) |>
    dplyr::filter(!is.na(index)) |>
    calculate_rppi_changes(
      index_col = "index",
      group_col = "name_simplified"
    ) |>
    dplyr::mutate(
      name_simplified = stringr::str_remove(name_simplified, "ivar_")
    ) |>
    dplyr::left_join(ivar_cities, by = "name_simplified") |>
    dplyr::mutate(
      name_muni = ifelse(name_simplified == "brazil", "Brazil", name_muni),
      abbrev_state = ifelse(name_simplified == "brazil", "BR", abbrev_state)
    ) |>
    dplyr::select(
      date,
      name_muni,
      index,
      chg,
      acum12m,
      name_simplified,
      abbrev_state
    )
}

#' Get Secovi-SP Rent Index
#'
#' @details
#' Secovi-SP rent price index for São Paulo. Wrapper around get_secovi() that
#' extracts and formats rent price data as RPPI.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m
#'
#' @keywords internal
get_rppi_secovi_sp <- function(
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Try cached first
  if (cached) {
    data <- try_rppi_cached("rent", "Secovi-SP")
    if (!is.null(data)) return(data)
  }

  # Get fresh data via get_secovi
  get_secovi(
    table = "rent",
    cached = FALSE,
    quiet = quiet,
    max_retries = max_retries
  ) |>
    dplyr::filter(category == "rent", variable == "rent_price") |>
    dplyr::rename(index = value) |>
    dplyr::mutate(name_muni = "S\u00e3o Paulo") |>
    dplyr::select(date, name_muni, index) |>
    calculate_rppi_changes(index_col = "index")
}

#' Get FipeZap RPPI
#'
#' @details
#' The FipeZap Index is a monthly median stratified index across ~20 Brazilian cities,
#' based on online listings from Zap Imóveis. Includes residential and commercial markets,
#' both sale and rent, stratified by number of rooms. The overall city index is a weighted
#' sum of median prices by room/region. Residential index includes only apartments, studios,
#' and flats. National index: `name_muni == 'Brazil'` (after standardization).
#'
#' @param city City name or "all" (default). Filtering by city doesn't save processing time.
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, market, rent_sale, variable, rooms, value
#'
#' @keywords internal
get_rppi_fipezap <- function(
  city = "all",
  cached = FALSE,
  quiet = FALSE,
  max_retries = 3L
) {
  # Try cached first
  if (cached) {
    data <- tryCatch(
      {
        df <- get_dataset("rppi", "fipezap", source = "github")
        if (city != "all" && city %in% unique(df$name_muni)) {
          df <- dplyr::filter(df, name_muni == city)
        }
        df
      },
      error = function(e) NULL
    )

    if (!is.null(data)) return(data)
  }

  # Download Excel with retry
  url <- "https://downloads.fipe.org.br/indices/fipezap/fipezap-serieshistoricas.xlsx"
  temp_path <- download_excel_with_retry(url, max_retries, quiet)

  # Get city sheet names (exclude summary sheets)
  sheet_names <- readxl::excel_sheets(temp_path) |>
    stringr::str_subset("(Resumo)|(Aux)", negate = TRUE)
  city_names <- stringr::str_to_title(sheet_names)

  # Import function for each sheet
  import_sheet <- function(sheet) {
    range <- get_range(temp_path, sheet)

    # Fix range if needed (ensure column BD is included)
    if (!stringr::str_detect(range, "BD")) {
      max_col <- stringr::str_extract(
        stringr::str_match(range, ":[A-Z]+[0-9]"),
        "[A-Z]+"
      )
      n1 <- stringr::str_locate(range, max_col)[, 1]
      n2 <- stringr::str_locate(range, max_col)[, 2]
      range <- paste0(
        stringr::str_sub(range, 1, n1 - 1),
        "BD",
        stringr::str_sub(range, n2 + 1, nchar(range))
      )
    }

    readxl::read_excel(
      temp_path,
      sheet,
      skip = 4,
      col_names = fipezap_col_names(),
      range = range
    ) |>
      dplyr::mutate(dplyr::across(dplyr::where(is.character), as.numeric))
  }

  # Process all sheets
  fipezap <- parallel::mclapply(sheet_names, import_sheet)
  names(fipezap) <- city_names

  # Stack and clean
  result <- dplyr::bind_rows(fipezap, .id = "name_muni") |>
    tidyr::pivot_longer(
      cols = dplyr::where(is.numeric),
      names_to = "info",
      values_to = "value"
    ) |>
    tidyr::separate_wider_delim(
      info,
      delim = "-",
      names = c("market", "rent_sale", "variable", "rooms")
    ) |>
    dplyr::mutate(date = lubridate::ymd(date)) |>
    dplyr::select(date, name_muni, market, rent_sale, variable, rooms, value)

  # Filter by city if specified
  if (city != "all" && city %in% unique(result$name_muni)) {
    result <- dplyr::filter(result, name_muni == city)
  }

  result
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


#' Get QuintoAndar ImovelWeb Rental Index (IQAIW)
#'
#' @details
#' The IQAIW (Índice QuintoAndar ImovelWeb) is a rental index for major Brazilian
#' cities. The index is based on both new rental contracts (managed by QuintoAndar)
#' and online listings from QuintoAndar's listings (including ImovelWeb).
#' The IQAIW was develoepd in 2023 and replaced the former IQA index. Given the
#' change in methodology and data sources, the IQAIW is not directly comparable to
#' the IQA index.
#' Formally, the index is a hedonic double imputed index, controlling for quality
#' changes using a flexible GAM specification with location variables. In this
#' sense, the IQAIW is more theoretically sound than median stratified indices
#' like FipeZap or the former IQA. The mixture of listings and contracts, however,
#' lacks theoretical support and seems to be mainly driven by branding purposes.
#' The ImovelWeb brand was purchased by QuintoAndar in 2021-22 and the IQAIW
#' symbolizes the merging of both brands. In other words, the original IQA could've
#' been improved simply by adopting a hedonic methodology, without the need to
#' mix data sources.
#'
#' @param cached Logical. If TRUE, loads from GitHub cache
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, price_m2
#'
#' @keywords internal
get_rppi_iqaiw <- function(cached = FALSE, quiet = FALSE, max_retries = 3L) {
  # Try cached first
  if (cached) {
    data <- tryCatch(
      {
        import_cached("rppi_iqaiw", quiet = quiet)
      },
      error = function(e) NULL
    )
    if (!is.null(data)) return(data)
  }

  # Download CSV with retry
  url <- "https://publicfiles.data.quintoandar.com.br/indice_quintoandar_imovelweb/index_quintoandar_imovelweb_serie.csv"

  dat <- download_with_retry(
    function() {
      readr::read_csv(url, col_types = "Dccddd", show_col_types = FALSE)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "IQAIW CSV from QuintoAndar"
  )

  # Expected column structure
  expected_names <- c(
    "ts_date",
    "city_name",
    "house_room",
    "est_price",
    "chg",
    "acum12m"
  )

  new_names <- c("date", "name_muni", "rooms", "price_m2", "chg", "acum12m")

  # City name mapping
  convert_city_names <- function(city) {
    vlname <- c(
      "bhe" = "Belo Horizonte",
      "bsb" = "Brasília",
      "cur" = "Curitiba",
      "poa" = "Porto Alegre",
      "rio" = "Rio de Janeiro",
      "spo" = "São Paulo"
    )
    return(unname(vlname[city]))
  }

  # Validate column structure
  if (!all(expected_names %in% names(dat))) {
    cli::cli_abort(c(
      "x" = "IQAIW data format has changed",
      "i" = "Expected columns: {.val {expected_names}}",
      "i" = "Found columns: {.val {names(dat)}}",
      "i" = "Please check the source or contact package maintainer"
    ))
  }

  # Clean and transform
  names(expected_names) <- new_names

  clean_dat <- dat |>
    dplyr::rename(dplyr::all_of(expected_names)) |>
    dplyr::filter(!is.na(price_m2)) |>
    dplyr::mutate(name_muni = convert_city_names(name_muni)) |>
    dplyr::mutate(
      index = price_m2 / first(price_m2) * 100,
      .by = "name_muni"
    ) |>
    dplyr::select(
      date,
      name_muni,
      index,
      chg,
      acum12m,
      price_m2
    )

  return(clean_dat)
}
