#' Get FGV IBRE Confidence Indicators
#'
#' @description
#' Loads construction confidence indicators from FGV IBRE including confidence
#' indices, expectation indicators, and INCC price indices. FGV data is not
#' available via API; this function fetches the pre-processed dataset from the
#' package's GitHub release.
#'
#' @param table Character. Which dataset to return: "indicators" (default) or "all".
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#'
#' @return Tibble with FGV IBRE indicators. Includes metadata attributes:
#'   source, download_time.
#'
#' @keywords internal
get_fgv_ibre <- function(
  table = "indicators",
  quiet = FALSE
) {
  valid_tables <- c("indicators")

  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries = 3,
    allow_all = TRUE
  )

  fgv_data <- fetch_github_release_asset("fgv_ibre", quiet = quiet)

  if (is.null(fgv_data)) {
    cli::cli_abort(c(
      "FGV IBRE data is not available",
      "x" = "Could not fetch the dataset from the GitHub release",
      "i" = "FGV data is not web-scrapable; the package distributes it via GitHub releases only"
    ))
  }

  fgv_data <- attach_dataset_metadata(
    fgv_data,
    source = "github",
    category = table
  )

  return(fgv_data)
}

# Load FGV Local CSV -------------------------------------------------------

#' Load FGV IBRE Data from a Local CSV Export
#'
#' Reads and tidies the semicolon-delimited CSV downloaded from the FGV IBRE
#' portal (<https://autenticacao-ibre.fgv.br/ProdutosDigitais/>). Called by the
#' targets pipeline when the local file changes.
#'
#' @param path Path to the CSV file (e.g. `"data-raw/xgdvConsulta.csv"`).
#' @return Tibble with columns: date, name_simplified, value, name_series,
#'   code_series, unit, source.
#' @keywords internal
#' @noRd
fetch_fgv_local <- function(path) {
  fgv_raw <- readr::read_delim(
    path,
    delim = ";",
    locale = readr::locale(decimal_mark = ",", encoding = "ISO-8859-1"),
    na = " - ",
    col_types = "cddddddddddddddd",
    show_col_types = FALSE
  )

  fgv_long <- fgv_raw |>
    dplyr::rename(date = Data) |>
    dplyr::mutate(date = readr::parse_date(date, format = "%m/%Y")) |>
    tidyr::pivot_longer(-date, names_to = "name_series")

  fgv_coded <- fgv_long |>
    dplyr::mutate(
      code_series = stringr::str_extract(name_series, "(?<=\\()\\d{7}(?=\\))"),
      code_series = as.numeric(code_series)
    ) |>
    dplyr::select(-name_series)

  fgv_data <- fgv_coded |>
    dplyr::left_join(fgv_dict, by = "code_series") |>
    dplyr::left_join(fgv_key, by = "code_series") |>
    dplyr::select(
      date,
      name_simplified,
      value,
      name_series,
      code_series,
      unit,
      source
    ) |>
    dplyr::filter(!is.na(value))

  fgv_data <- attach_dataset_metadata(fgv_data, source = "web")

  return(fgv_data)
}

# fmt: skip
fgv_key <- tibble::tribble(
  ~code_series,      ~name_simplified,
       1463201,         "ivar_brazil",
       1463202,      "ivar_sao_paulo",
       1463203, "ivar_rio_de_janeiro",
       1463204, "ivar_belo_horizonte",
       1463205,   "ivar_porto_alegre",
       1428409,                "nuci",
       1416233,              "ie_cst",
       1416234,             "isa_cst",
       1416232,              "ic_cst",
       1464783,      "incc_brasil_di",
       1465235,         "incc_brasil",
       1464331,      "incc_brasil_10",
       1000379,    "incc_1o_decendio",
       1000366,    "incc_2o_decendio",
       1000370,                "incc"
)
# fmt: skip
fgv_dict <- tibble::tibble(
  id_series = 1:15,
  code_series = c(
    1463201, 1463202, 1463203, 1463204, 1463205, 1428409, 1416233, 1416234, 1416232,
    1464783, 1465235, 1464331, 1000379, 1000366, 1000370
  ),
  name_series = c(
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - M\u00e9dia Nacional",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - S\u00e3o Paulo",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Rio de Janeiro",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Belo Horizonte",
    "\u00cdndice de Varia\u00e7\u00e3o de Alugu\u00e9is Residenciais (IVAR) - Porto Alegre",
    "Sondagem da Constru\u00e7\u00e3o \u2013 N\u00edvel de Utiliza\u00e7\u00e3o da Capacidade Instalada",
    "IE-CST Com ajuste Sazonal - \u00cdndice de Expectativas da Constru\u00e7\u00e3o",
    "ISA-CST Com ajuste Sazonal - \u00cdndice da Situa\u00e7\u00e3o Atual da Constru\u00e7\u00e3o",
    "ICST Com ajuste Sazonal - \u00cdndice de Confian\u00e7a da Constru\u00e7\u00e3o",
    "INCC - Brasil - DI",
    "INCC - Brasil",
    "INCC - Brasil-10",
    "INCC - 1o Decendio",
    "INCC - 2o Decendio",
    "INCC - Fechamento Mensal"
  ),
  source = c(
    "FGV", "FGV", "FGV", "FGV", "FGV", "FGV", "FGV-SONDA", "FGV-SONDA", "FGV-SONDA",
    "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC", "FGV-INCC"
  ),
  unit = c(
    "Indice", "Indice", "Indice", "Indice", "Indice", "Percentual", "Indicador",
    "Indicador", "Indicador", "\u00cdndice", "\u00cdndice", "\u00cdndice", "Percentual",
    "Percentual", "Percentual"
  )
)
