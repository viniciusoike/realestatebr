#' Import Real Estate data from the Brazilian Central Bank
#'
#' @description
#' Imports real estate data from BCB including credit sources, applications,
#' financed units, and real estate indices.
#'
#' @param table Character. One of `'accounting'`, `'application'`, `'indices'`,
#'   `'sources'`, `'units'`, or `'all'` (default).
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Tibble with BCB real estate data. Includes metadata attributes:
#'   source, download_time.
#'
#' @source \url{https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario}
#' @keywords internal
get_bcb_realestate <- function(
  table = "all",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("accounting", "application", "indices", "sources", "units")

  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  cli_user("Downloading real estate data from BCB API", quiet = quiet)

  bcb <- rlang::try_fetch(
    download_bcb_realestate(quiet = quiet, max_retries = max_retries),
    error = function(cnd) {
      if (!quiet) {
        cli::cli_warn("BCB API download failed: {cnd$message}")
      }
      NULL
    }
  )

  if (is.null(bcb)) {
    data <- fallback_to_github_cache("bcb_realestate", quiet = quiet)
    if (!is.null(data)) {
      clean_bcb <- attach_dataset_metadata(data, source = "github")
    } else {
      cli::cli_abort(c(
        "BCB API failed after {max_retries} attempts",
        "x" = "GitHub release is also unavailable",
        "i" = "The BCB API may be temporarily down"
      ))
    }
  } else {
    clean_bcb <- clean_bcb_realestate(bcb)
    clean_bcb <- attach_dataset_metadata(clean_bcb, source = "web")
  }

  # Return full cleaned table ----
  if (table == "all") {
    return(clean_bcb)
  }

  # Pivot to wide format for specific tables ----
  tbl_bcb_wider <- function(cat, id_cols, names_from) {
    clean_bcb |>
      dplyr::filter(category == cat, !stringr::str_detect(type, "[0-9]")) |>
      tidyr::pivot_wider(
        id_cols = id_cols,
        names_from = names_from,
        values_from = "value",
        names_sep = "_",
        names_repair = "universal"
      ) |>
      dplyr::rename_with(~ stringr::str_remove(.x, "(_br)|(br$)"))
  }

  params <- dplyr::tibble(
    category_label = c(
      "units",
      "accounting",
      "indices",
      "sources",
      "application"
    ),
    cat = c("imoveis", "contabil", "indices", "fontes", "direcionamento"),
    id_cols = list(c("date", "abbrev_state"), "date", "date", "date", "date"),
    names_from = list(
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1"),
      c("type", "v1", "v2")
    )
  )

  tbl_bcb <- dplyr::mutate(
    params,
    tab = purrr::pmap(list(cat, id_cols, names_from), tbl_bcb_wider)
  ) |>
    dplyr::filter(category_label == table) |>
    tidyr::unnest(cols = tab) |>
    dplyr::select(-category_label, -cat, -id_cols, -names_from)

  source_val <- attr(clean_bcb, "source", exact = TRUE)
  if (is.null(source_val)) {
    source_val <- "web"
  }

  tbl_bcb <- attach_dataset_metadata(
    tbl_bcb,
    source = source_val,
    category = table
  )

  n_records <- nrow(tbl_bcb)
  cli_user(
    "BCB real estate data retrieved: {n_records} records",
    quiet = quiet
  )

  return(tbl_bcb)
}

#' Download raw BCB real estate data from the API
#'
#' @param quiet Logical controlling messages
#' @param max_retries Maximum number of retry attempts
#' @return Raw tibble from BCB API endpoint
#' @keywords internal
download_bcb_realestate <- function(quiet = FALSE, max_retries = 3L) {
  url <- "https://olinda.bcb.gov.br/olinda/servico/MercadoImobiliario/versao/v1/odata/mercadoimobiliario?$format=text/csv&$select=Data,Info,Valor"

  temp_path <- download_csv(url, max_retries = max_retries, quiet = quiet)
  raw <- readr::read_csv(temp_path, col_types = "Dcc")

  return(raw)
}

clean_bcb_realestate <- function(df) {
  # Named vector to swap hyphenated tokens before splitting on underscore
  new_names <- c(
    "home_equity" = "home-equity",
    "risco_operacao" = "risco-operacao",
    "d_mais" = "d-mais",
    "ivg_r" = "ivg-r",
    "mvg_r" = "mvg-r"
  )

  df <- df |>
    dplyr::rename(date = Data, series_info = Info, value = Valor) |>
    dplyr::mutate(
      value = stringr::str_replace(value, ",", "."),
      value = suppressWarnings(as.numeric(value)),
      series_info = stringr::str_replace_all(series_info, new_names),
      year = lubridate::year(date),
      month = lubridate::month(date),
    )

  df <- tidyr::separate_wider_delim(
    df,
    series_info,
    delim = "_",
    names = c(
      "category",
      "type",
      "v1",
      "v2",
      "v3",
      "v4",
      "v5",
      "v6",
      "v7",
      "v8"
    ),
    too_few = "align_start",
    cols_remove = FALSE
  )

  uf_abb <- "br|ro|ac|am|rr|pa|ap|to|ma|pi|ce|rn|pb|pe|al|se|ba|mg|es|rj|sp|pr|sc|rs|ms|mt|go|df"

  df <- df |>
    dplyr::mutate(
      abbrev_state = stringr::str_extract(
        stringr::str_sub(series_info, -2, -1),
        uf_abb
      ),
      abbrev_state = stringr::str_to_upper(abbrev_state),
      abbrev_state = ifelse(is.na(abbrev_state), "BR", abbrev_state)
    )

  df <- dplyr::select(df, dplyr::where(~ !all(is.na(.x))))
  df <- dplyr::arrange(df, date)

  return(df)
}
