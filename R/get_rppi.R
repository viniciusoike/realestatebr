# Suppress R CMD check NOTEs for NSE in dplyr
utils::globalVariables(c("price_m2"))

.rppi_cols <- c("date", "name_muni", "index", "chg", "acum12m")

#' Standardize City Names Across RPPI Sources
#'
#' @param x Character vector of city names
#' @return Standardized city names
#' @keywords internal
#' @noRd
standardize_city_names <- function(x) {
  y <- stringr::str_replace(x, "Brasil", "Brazil")
  y <- stringr::str_replace(y, "(?i)\u00cdndice\\s+FipeZAP\\+?", "Brazil")
  y <- stringr::str_to_title(y)
  y <- stringr::str_squish(y)

  return(y)
}

#' Harmonize FipeZap Data for Stacking
#'
#' @param dat FipeZap data tibble
#' @param transaction_type "sale" or "rent" to filter for stacking
#' @return Harmonized tibble with standard RPPI columns
#' @keywords internal
harmonize_fipezap_for_stacking <- function(dat, transaction_type = NULL) {
  if (!any(c("sale", "rent") %in% transaction_type)) {
    cli::cli_abort("Invalid transaction type: {.val {transaction_type}}")
  }

  filtered_data <- dat |>
    # Filter to residential data with total rooms only
    dplyr::filter(
      market == "residential",
      rooms == "total",
      variable %in% c("index", "chg", "acum12m"),
      rent_sale == !!transaction_type
    )

  # Convert to wide format with standard columns
  harmonized_data <- filtered_data |>
    tidyr::pivot_wider(
      id_cols = c("date", "name_muni"),
      names_from = "variable",
      values_from = "value"
    ) |>
    dplyr::mutate(name_muni = standardize_city_names(name_muni)) |>
    dplyr::select(dplyr::all_of(.rppi_cols))

  return(harmonized_data)
}

#' Standardize RPPI Structure
#'
#' @param dat Input tibble from any RPPI source
#' @return Standardized tibble with consistent columns
#' @keywords internal
standardize_rppi_structure <- function(dat) {
  # Handle IQA special case (has rent_price instead of index)
  if ("rent_price" %in% names(dat) && !"index" %in% names(dat)) {
    dat <- dat |>
      dplyr::mutate(
        index = rent_price / dplyr::first(rent_price) * 100,
        .by = name_muni
      )
  }

  dat <- dat |>
    dplyr::rename(dplyr::any_of(c("name_muni" = "name_geo")))

  standardized_data <- dat |>
    dplyr::mutate(name_muni = standardize_city_names(name_muni)) |>
    dplyr::select(dplyr::all_of(.rppi_cols))

  return(standardized_data)
}


#' Get Stacked RPPI Data
#'
#' @details
#' Stacks multiple Brazilian residential property price indices into a single tibble
#' with consistent columns for easy comparison. Handles different RPPI sources (IGMI-R,
#' IVG-R, FipeZap, IVAR, IQAIW) and standardizes their formats.
#'
#' Sale stack: IGMI-R, IVG-R, FipeZap. Rent stack: IVAR, IQAIW, FipeZap.
#' Use get_dataset("rppi", table) for individual indices (IQA, IQAIW, Secovi-SP, etc.).
#'
#' @param table Character. "sale", "rent", or "all"
#' @param quiet Logical. If TRUE, suppresses messages
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, source
#'  (plus transaction_type if table="all")
#'
#' @keywords internal
get_rppi <- function(
  table = "sale",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c(
    "sale",
    "rent",
    "fipezap",
    "ivgr",
    "igmi",
    "iqa",
    "iqaiw",
    "ivar",
    "secovi_sp"
  )
  validate_dataset_params(
    table = table,
    valid_tables = valid_tables,
    quiet = quiet,
    max_retries = max_retries,
    allow_all = TRUE
  )

  rppi_fns <- list(
    fipezap = get_rppi_fipezap,
    ivgr = get_rppi_ivgr,
    igmi = get_rppi_igmi,
    iqa = get_rppi_iqa,
    iqaiw = get_rppi_iqaiw,
    ivar = get_rppi_ivar,
    secovi_sp = get_rppi_secovi_sp
  )

  if (table %in% names(rppi_fns)) {
    return(rppi_fns[[table]](
      quiet = quiet,
      max_retries = max_retries
    ))
  }

  if (table == "sale") {
    igmi <- get_rppi_igmi(quiet, max_retries)
    ivgr <- get_rppi_ivgr(quiet, max_retries)
    fipezap <- get_rppi_fipezap(quiet = quiet, max_retries = max_retries)

    series <- list(
      "IGMI-R" = standardize_rppi_structure(igmi),
      "IVG-R" = standardize_rppi_structure(ivgr),
      "FipeZap" = harmonize_fipezap_for_stacking(fipezap, "sale")
    )
  } else if (table == "rent") {
    ivar <- get_rppi_ivar(quiet, max_retries)
    iqaiw <- get_rppi_iqaiw(quiet, max_retries)
    fipezap <- get_rppi_fipezap(quiet = quiet, max_retries = max_retries)

    series <- list(
      "IQAIW" = standardize_rppi_structure(dplyr::filter(
        iqaiw,
        rooms == "total"
      )),
      "IVAR" = standardize_rppi_structure(ivar),
      "FipeZap" = harmonize_fipezap_for_stacking(fipezap, "rent")
    )
  } else {
    series <- list(
      "sale" = get_rppi("sale", quiet, max_retries),
      "rent" = get_rppi("rent", quiet, max_retries)
    )
    stacked_data <- dplyr::bind_rows(series, .id = "transaction_type")

    if (!quiet) {
      cli::cli_inform(
        "\u2713 RPPI (all): {nrow(stacked_data)} records"
      )
    }

    return(stacked_data)
  }

  stacked_data <- dplyr::bind_rows(series, .id = "source")

  if (!quiet) {
    cli::cli_inform(
      "\u2713 RPPI ({table}): {nrow(stacked_data)} records from {length(unique(stacked_data$source))} sources"
    )
  }

  return(stacked_data)
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
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_geo, index, chg, acum12m
#'
#' @references Banco Central do Brasil (2018) "Indice de Valores de Garantia de
#' Imoveis Residenciais Financiados (IVG-R). Seminario de Metodologia do IBGE."
#'
#' @keywords internal
get_rppi_ivgr <- function(quiet = FALSE, max_retries = 3L) {
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
  ivgr <- ivgr |>
    dplyr::mutate(name_geo = "Brazil") |>
    dplyr::select(date, name_geo, index) |>
    calculate_rppi_changes(index_col = "index")

  return(ivgr)
}

#' Get the IGMI Sales Index
#'
#' @details
#' The IGMI-R (Residential Real Estate Index) is a hedonic sales index based on
#' bank appraisal reports, available for Brazil + 10 capital cities. Hedonic indices
#' account for both composition bias and quality differentials across the housing stock.
#' Maintained by ABECIP in partnership with FGV.
#'
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m
#'
#' @keywords internal
get_rppi_igmi <- function(quiet = FALSE, max_retries = 3L) {
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

  igmi <- readxl::read_excel(
    temp_path,
    skip = 4,
    .name_repair = janitor::make_clean_names
  )

  cols_rename <- c("date" = "mes")
  cols_drop <- c("var_percent_12_meses")

  igmi_parse_dates <- function(dat) {
    dat |>
      dplyr::mutate(date = readr::parse_date(date, format = "%Y %m")) |>
      dplyr::filter(!is.na(date))
  }

  igmi <- igmi |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::select(-dplyr::any_of(cols_drop))

  igmi <- suppressWarnings(igmi_parse_dates(igmi))

  igmi <- igmi |>
    tidyr::pivot_longer(
      cols = -date,
      names_to = "name_simplified",
      values_to = "index"
    ) |>
    calculate_rppi_changes(
      index_col = "index",
      group_col = "name_simplified"
    )

  igmi <- igmi |>
    dplyr::left_join(dim_geo, by = dplyr::join_by(name_simplified)) |>
    dplyr::select(dplyr::all_of(.rppi_cols))

  return(igmi)
}

#' Get QuintoAndar Rental Index (IQA)
#'
#' @details
#' The IQA (QuintoAndar Rental Index) is a median stratified index for Rio de Janeiro
#' and Sao Paulo, based on new rent contracts managed by QuintoAndar. Includes only
#' apartments, studios, and flats. Note: IQA provides raw prices (not index numbers),
#' so `rent_price` is the median rent per square meter.
#'
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, rent_price, chg, acum12m
#'
#' @keywords internal
get_rppi_iqa <- function(quiet = FALSE, max_retries = 3L) {
  url <- "https://publicfiles.data.quintoandar.com.br/Indice_QuintoAndar.csv"
  iqa <- download_with_retry(
    function() readr::read_csv(url, col_types = "cDn", show_col_types = FALSE),
    max_retries = max_retries,
    quiet = quiet,
    desc = "IQA CSV from QuintoAndar"
  )

  cols_rename <- c(
    "date" = "month",
    "name_muni" = "city_name",
    "rent_price" = "weighted_median_contract_rent_per_sqm"
  )

  iqa <- iqa |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::mutate(
      rent_price = as.numeric(rent_price),
      name_muni = standardize_city_names(name_muni),
      index = rent_price / dplyr::first(rent_price) * 100,
      .by = "name_muni"
    )

  iqa <- iqa |>
    calculate_rppi_changes(index_col = "index", group_col = "name_muni") |>
    dplyr::select(dplyr::all_of(.rppi_cols))

  return(iqa)
}

#' Get IVAR Rent Index
#'
#' @details
#' The IVAR (Residential Rent Variation Index) is a repeat-rent index from IBRE/FGV,
#' comparing the same housing unit over time. Based on rental contracts from brokers.
#' Available for 4 major cities (Sao Paulo, Rio, Porto Alegre, Belo Horizonte); the
#' national index is a weighted average. More theoretically sound than IGP-M for rent
#' contracts as it measures only rent prices.
#'
#' @note IVAR's underlying source (FGV) is not accessible via web scraping;
#' when the static `fgv_data` object is unavailable, this function falls back
#' to the package's GitHub release.
#'
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts (not used for this data source)
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, name_simplified, abbrev_state
#'
#' @keywords internal
get_rppi_ivar <- function(quiet = FALSE, max_retries = 3L) {
  if (!exists("fgv_data") || !exists("dim_city")) {
    if (!quiet) {
      cli::cli_inform(c(
        "i" = "IVAR source data not available, loading from GitHub release..."
      ))
    }

    data <- fallback_to_github_cache("rppi_ivar", quiet = quiet)

    if (is.null(data)) {
      cli::cli_abort(c(
        "IVAR data not available",
        "x" = "Source data (fgv_data) is not accessible and GitHub release is unavailable",
        "i" = "IVAR requires static FGV data that is not web-scrapable",
        "i" = "Please retry: get_dataset('rppi', 'ivar', source = 'github')"
      ))
    }

    return(data)
  }

  # City mapping for IVAR cities
  ivar_cities <- dim_city |>
    dplyr::filter(code_muni %in% c(3550308, 4314902, 3304557, 3106200)) |>
    dplyr::select(name_simplified, name_muni, abbrev_state)

  cols_rename <- c("index" = "value")

  # Extract and process IVAR data
  ivar <- fgv_data |>
    dplyr::rename(dplyr::all_of(cols_rename)) |>
    dplyr::filter(
      stringr::str_detect(name_simplified, "^ivar"),
      !is.na(index)
    ) |>
    calculate_rppi_changes(
      index_col = "index",
      group_col = "name_simplified"
    )

  ivar <- ivar |>
    dplyr::mutate(
      name_simplified = stringr::str_remove(name_simplified, "ivar_")
    ) |>
    dplyr::left_join(ivar_cities, by = dplyr::join_by(name_simplified)) |>
    dplyr::mutate(name_muni = standardize_city_names(name_muni)) |>
    dplyr::select(dplyr::all_of(.rppi_cols))

  return(ivar)
}

#' Get Secovi-SP Rent Index
#'
#' @details
#' Secovi-SP rent price index for Sao Paulo. Wrapper around get_secovi() that
#' extracts and formats rent price data as RPPI.
#'
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m
#'
#' @keywords internal
get_rppi_secovi_sp <- function(quiet = FALSE, max_retries = 3L) {
  dat <- get_secovi(
    table = "rent",
    quiet = quiet,
    max_retries = max_retries
  )

  # Get fresh data via get_secovi
  secovi <- dat |>
    dplyr::filter(name == "indice_de_locacao_residencial") |>
    dplyr::rename(index = value) |>
    dplyr::mutate(name_muni = "S\u00e3o Paulo") |>
    dplyr::select(date, name_muni, index) |>
    calculate_rppi_changes(index_col = "index")

  return(secovi)
}

#' Get FipeZap RPPI
#'
#' @details
#' The FipeZap Index is a monthly median stratified index across ~20 Brazilian cities,
#' based on online listings from Zap Imoveis. Includes residential and commercial markets,
#' both sale and rent, stratified by number of rooms. The overall city index is a weighted
#' sum of median prices by room/region. Residential index includes only apartments, studios,
#' and flats. National index: `name_muni == 'Brazil'` (after standardization).
#'
#' @param city City name or "all" (default). Filtering by city doesn't save processing time.
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts
#'
#' @return Tibble with columns: date, name_muni, market, rent_sale, variable, rooms, value
#'
#' @keywords internal
get_rppi_fipezap <- function(
  city = "all",
  quiet = FALSE,
  max_retries = 3L
) {
  url <- "https://downloads.fipe.org.br/indices/fipezap/fipezap-serieshistoricas.xlsx"
  temp_path <- download_excel(
    url,
    min_size = 1000,
    max_retries = max_retries,
    quiet = quiet
  )

  # Identify city sheet indices and names.
  # FIPE's XLSX stores sheet names as Latin-1 but readxl reports them as
  # UTF-8; readxl::read_excel() cannot resolve them by the returned string.
  # Workaround: filter non-city sheets by name (str_subset works fine), then
  # record their 1-based positions and pass those to read_excel instead.
  # tidyxl::xlsx_cells() handles accented names correctly, so get_range()
  # (which uses tidyxl) continues to receive the string name.
  all_sheets <- readxl::excel_sheets(temp_path)
  city_mask <- !stringr::str_detect(all_sheets, "(Resumo)|(Aux)")
  sheet_names <- all_sheets[city_mask]
  sheet_indices <- which(city_mask)

  city_names <- stringr::str_to_title(sheet_names)

  # Import one city sheet; use index for readxl, name for get_range.
  import_sheet <- function(sheet_name, sheet_idx) {
    range <- get_range(temp_path, sheet_name)

    # Ensure column BD is included in the range
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

    col_types_vec <- c(
      "date",
      rep("numeric", length(build_fipezap_col_names()) - 1)
    )

    dat <- readxl::read_excel(
      temp_path,
      sheet_idx,
      skip = 4,
      col_names = build_fipezap_col_names(),
      col_types = col_types_vec,
      range = range,
      na = c("", "#N/A", ".")
    )

    return(dat)
  }

  # Process all city sheets
  fipezap <- mapply(import_sheet, sheet_names, sheet_indices, SIMPLIFY = FALSE)
  names(fipezap) <- city_names
  # Stack and clean
  series <- dplyr::bind_rows(fipezap, .id = "name_muni")

  fipe <- series |>
    tidyr::pivot_longer(
      dplyr::where(is.numeric),
      names_to = "info",
      values_to = "value"
    ) |>
    tidyr::separate_wider_delim(
      info,
      delim = "-",
      names = c("market", "rent_sale", "variable", "rooms")
    )

  cols_fipe <- c(
    "date",
    "name_muni",
    "market",
    "rent_sale",
    "variable",
    "rooms",
    "value"
  )

  fipe <- fipe |>
    dplyr::mutate(
      date = lubridate::ymd(date),
      name_muni = standardize_city_names(name_muni)
    ) |>
    dplyr::select(dplyr::all_of(cols_fipe))

  if (city != "all" && city %in% unique(fipe$name_muni)) {
    fipe <- dplyr::filter(fipe, name_muni == city)
  }

  return(fipe)
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
build_fipezap_col_names <- function() {
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
#' The IQAIW (Indice QuintoAndar ImovelWeb) is a rental index for major Brazilian
#' cities. The index is based on both new rental contracts (managed by QuintoAndar)
#' and online listings from QuintoAndar's listings (including ImovelWeb).
#' The IQAIW was developed in 2023 and replaced the former IQA index. Given the
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
#' @param quiet Logical. If TRUE, suppresses warnings
#' @param max_retries Integer. Maximum retry attempts for downloads
#'
#' @return Tibble with columns: date, name_muni, index, chg, acum12m, price_m2
#'
#' @keywords internal
get_rppi_iqaiw <- function(quiet = FALSE, max_retries = 3L) {
  url <- "https://publicfiles.data.quintoandar.com.br/indice_quintoandar_imovelweb/index_quintoandar_imovelweb_serie.csv"

  dat <- download_with_retry(
    function() {
      readr::read_csv(url, col_types = "Dccddd", show_col_types = FALSE)
    },
    max_retries = max_retries,
    quiet = quiet,
    desc = "IQAIW CSV from QuintoAndar"
  )

  expected_cols <- c(
    "ts_date",
    "city_name",
    "house_room",
    "est_price",
    "chg",
    "acum12m"
  )

  cols_rename <- c(
    "date" = "ts_date",
    "name_muni" = "city_name",
    "rooms" = "house_room",
    "price_m2" = "est_price"
  )

  # City name mapping
  convert_city_names <- function(city) {
    vlname <- c(
      "bhe" = "Belo Horizonte",
      "bsb" = "Bras\u00edlia",
      "cur" = "Curitiba",
      "poa" = "Porto Alegre",
      "rio" = "Rio de Janeiro",
      "spo" = "S\u00e3o Paulo"
    )
    return(unname(vlname[city]))
  }

  if (!all(expected_cols %in% names(dat))) {
    cli::cli_abort(c(
      "x" = "IQAIW data format has changed",
      "i" = "Expected columns: {.val {expected_cols}}",
      "i" = "Found columns: {.val {names(dat)}}",
      "i" = "Please check the source or contact package maintainer"
    ))
  }

  iqaiw <- dat |>
    dplyr::rename(dplyr::any_of(cols_rename)) |>
    dplyr::filter(!is.na(price_m2))

  .rppi_cols_iqaiw <- c("date", "name_muni", "rooms", "index", "chg", "acum12m")

  iqaiw <- iqaiw |>
    dplyr::mutate(
      name_muni = convert_city_names(name_muni),
      # Standardize with FipeZap
      rooms = dplyr::if_else(rooms == "city", "total", as.character(rooms))
    ) |>
    dplyr::mutate(
      index = price_m2 / dplyr::first(price_m2) * 100,
      .by = "name_muni"
    ) |>
    dplyr::select(dplyr::all_of(.rppi_cols_iqaiw))

  return(iqaiw)
}
