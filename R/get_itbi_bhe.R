#' Dictionary variable for ITBI
#'
#' @return A `list` containing a url, column names, and column types to facilitate
#' data import.
#' @noRd
itbi_bhe_dict <- function() {

  url <- "https://ckan.pbh.gov.br/dataset/fdb1a8b6-1ef5-4084-bda5-e9503d00d5c5/resource/0dfdafa8-562b-42ad-b241-bb542b8dcfc4/download/pda_-_itbi_-_2008_01_a_2024_01.csv"

  cnames <- c(
    "endereco", "bairro", "ano_de_construcao_unidade", "area_terreno_total",
    "area_construida_adquirida", "area_adquirida_unidades_somadas",
    "padrao_acabamento_unidade", "fracao_ideal_adquirida",
    "tipo_construtivo_preponderante",  "descricao_tipo_ocupacao_unidade",
    "valor_declarado", "valor_base_calculo", "zona_uso", "data_quitacao"
  )

  ctypes <- cols(
    endereco = col_character(),
    bairro = col_character(),
    ano_de_construcao_unidade = col_number(),
    area_terreno_total = col_number(),
    area_construida_adquirida = col_number(),
    area_adquirida_unidades_somadas = col_number(),
    padrao_acabamento_unidade = col_character(),
    fracao_ideal_adquirida = col_number(),
    tipo_construtivo_preponderante = col_character(),
    descricao_tipo_ocupacao_unidade = col_character(),
    valor_declarado = col_number(),
    valor_base_calculo = col_number(),
    zona_uso = col_character(),
    data_quitacao = col_date(format = "%d/%m/%Y")
  )

  out <- list(
    url = url,
    col_names = cnames,
    col_types = ctypes
  )

  return(out)

}

#' Get Property Tax Records
#'
#' Imports and cleans property tax records for main Brazilian Cities. Currently
#' available only for Belo Horizonte and São Paulo. Unlike other functions,
#' there is no cached data available.
#'
#' @param city Must one of 'bhe', 'spo', 'Belo Horizonte', or 'São Paulo'
#'
#' @return A `tibble`
#' @export
get_itbi <- function(city = "bhe") {

  available_cities_itbi <- c(
    "bhe", "Belo Horizonte"
  )

  if (!any(city %in% available_cities_itbi)) {

    stop(glue::glue("Argument 'city' must be one of {paste(available_cities_itbi, collapse = ', ')}."))

    }

  if (city == "bhe" | city == "Belo Horizonte") {

    dict <- itbi_bhe_dict()

    url <- dict$url
    col_names <- dict$col_names
    col_types <- dict$col_types

    itbi <- readr::read_delim(
      url,
      n_max = 1000,
      delim = ";",
      locale = readr::locale(
        decimal_mark = ",",
        grouping_mark = ".",
        date_format = "%d/%m/%Y"
      ),
      na = " -   ",
      col_names = col_names,
      col_types = col_types,
      skip = 1
    )

  }

  return(itbi)

}
