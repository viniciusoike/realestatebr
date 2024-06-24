
get_itbi_spo <- function(year, cached) {

  stopifnot(year %in% 2019:2023)

  if (cached) {
    itbi <- import_cached("itbi_spo")
    itbi <- dplyr::filter(itbi, year == local(year))
    return(itbi)
  }

  path_itbi <- download_itbi_sp()


}

download_itbi_sp <- function() {

  # Scrape links for download
  url <- "https://www.prefeitura.sp.gov.br/cidade/secretarias/fazenda/acesso_a_informacao/index.php?p=31501"
  pag <- xml2::read_html(url)

  links1 <- pag |>
    rvest::html_elements(xpath = "//ul/li/strong/u/a") |>
    rvest::html_attrs() |>
    unlist()

  links2 <- pag |>
    rvest::html_elements(xpath = "//ul/li/u/a") |>
    rvest::html_attrs() |>
    unlist()

  links3 <- pag |>
    rvest::html_elements(xpath = "//ul/li/strong/a") |>
    rvest::html_attrs() |>
    unlist()

  links <- c(links1, links2, links3)
  links <- links[stringr::str_detect(links, "xlsx$")]

  # url.download <- paste0("https://www.prefeitura.sp.gov.br", links)

  filename <- basename(links)
  destfile <- tempfile(filename)
  # destfile <- here::here(fld, filename)
  # Download
  for (i in seq_along(links)) {
    try(
      download.file(
        url = links[i],
        destfile = destfile[i],
        mode = "wb",
        quiet = TRUE)
      )
  }
  # Return paths to the downloaded files
  return(destfile)

}


import_itbi <- function(path) {

  sheets <- readxl::excel_sheets(path)
  data_sheets <- sheets[stringr::str_detect(sheets, "[0-9][0-9][0-9][0-9]")]

  data <- parallel::mclapply(data_sheets, function(s) {
    readxl::read_excel(
      path,
      sheet = s,
      skip = 1,
      col_names = itbi_cols$names,
      col_types = itbi_cols$types,
      na = c("SN", "S/N", "SEM N")
      )
  })

  names(data) <- data_sheets
  data <- dplyr::bind_rows(data, .id = "yearmonth")
  clean_itbi(data)

}

itbi_cols <- list(
  names = c(
    "code_iptu_sql", "house_street", "house_number", "house_complement",
    "house_neighborhood", "house_location_info", "house_zipcode", "itbi_transaction",
    "itbi_transaction_value", "itbi_transaction_date", "itbi_valor_venal",
    "itbi_proportion", "itbi_valor_venal_ref", "itbi_base_value",
    "house_financing_method", "house_financed_value", "house_registry",
    "house_id_matricula", "iptu_sql_status", "house_land_area",
    "house_iptu_recuo", "house_iptu_fraction", "house_built_area", "iptu_landuse",
    "iptu_landuse_label", "iptu_type", "iptu_type_label", "iptu_year_built"
  ),
  types = c(
    "text", "text", "numeric", "text", "text", "text",
    "text", "text", "numeric", "guess", "numeric", "numeric",
    "numeric", "numeric", "text", "numeric", "text", "text",
    "text", "numeric", "numeric", "numeric", "numeric", "text",
    "text", "text", "text", "numeric")
)

clean_itbi <- function(data) {

  clean_df <- df |>
    dplyr::mutate(
      # Pad SQL IPTU identifier with zeros
      code_iptu_sql = stringr::str_pad(code_iptu_sql, width = 11, side = "left", pad = "0"),
      # Split SQL identifier into setor, quadra, lote, and verfying digit
      code_setor = stringr::str_sub(code_iptu_sql, 1, 3),
      code_quadra = stringr::str_sub(code_iptu_sql, 4, 6),
      code_lote = stringr::str_sub(code_iptu_sql, 7, 10),
      code_iptu_verificador = stringr::str_sub(code_iptu_sql, start = -1)
    )

  clean_df <- clean_df |>
    dplyr::mutate(
      # Simplify date to ymd
      itbi_transaction_date = lubridate::ymd(itbi_transaction_date),
      yearmonth = stringr::str_to_lower(yearmonth),
      date = readr::parse_date(
        yearmonth,
        format = "%b-%Y",
        locale = readr::locale(date_names = "pt")
      ),
      year = lubridate::year(ts_date),
      qtr = lubridate::quarter(ts_date),
      month = lubridate::month(ts_date)
    )

  clean_df <- clean_df |>
    dplyr::mutate(
      # Glue together a house_address
      house_address = stringr::str_glue("{house_street}, {house_number}, {house_neighborhood}, São Paulo"),
      house_address = stringr::str_replace_all(house_address, pattern = "  ", replacement = " ")
    )

  clean_df <- clean_df |>
    dplyr::select(-yearmonth) |>
    dplyr::select(ts_date, ts_year, house_address, dplyr::starts_with("itbi"), dplyr::everything())

  return(clean_df)

}
