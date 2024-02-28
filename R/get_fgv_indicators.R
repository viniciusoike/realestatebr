#' Get FGV Confidence Indicators
#'
#' Download and clean construction confidence indicators estimated and released
#' by the Getúlio Vargas Foundation (FGV).
#'
#' @inheritParams get_secovi
#'
#' @return A `tibble` containing all construction confidence indicator series from FGV.
#' @export
get_fgv_indicators <- function(cached = TRUE) {

  # Check if category argument is valid

  # Swap vector for categories
  # vl_category <- c(
  #   "used_capacity" = "nuci",
  #   "expectations" = "ie_cst",
  #   "confidence" = "ic_cst",
  #   "current" = "isa_cst",
  #   "incc_brasil_di" = "incc_brasil_di",
  #   "incc_brasil" = "incc_brasil",
  #   "incc_brasil_10" = "incc_brasil_10",
  #   "incc_1o_decendio" = "incc_1o_decendio",
  #   "incc_2o_decendio" = "incc_2o_decendio",
  #   "incc" = "incc"
  #   )

  # # Group all valid category options into a single vector
  # cat_options <- c("all", names(vl_category))
  # # Collapse into a single string for error output message
  # error_msg <- paste(cat_options, collapse = ", ")
  # # Check if 'category' is valid
  # if (!any(category %in% cat_options)) {
  #   stop(glue::glue("Category must be one of: {error_msg}."))
  # }
  # # Swap category with vars
  # vars <- ifelse(category == "all", vl_category, vl_category[category])
  #
  # if (cached) {
  #
  #   df <- import_cached("fgv_indicators")
  #   df <- dplyr::filter(df, name_simplified %in% vars)
  #
  # } else {
  #
  #   df <- dplyr::filter(fgv_data, name_simplified %in% vars)
  #
  # }
  #
  # if (all(names(df) %in% names(fgv_dict))) {
  #   df <- dplyr::left_join(df, fgv_dict, by = "code_series")
  # }
  #
  # df <- stats::na.omit(df)

  if (cached) {
    return(import_cached("fgv_indicators"))
  } else {
    return(fgv_data)
  }

  # return(df)

}

fgv_dict <- data.frame(
  id_series = 1:15,
  code_series = c(
    1463201, 1463202, 1463203, 1463204, 1463205, 1428409, 1416233, 1416234, 1416232,
    1464783, 1465235, 1464331, 1000379, 1000366, 1000370
  ),
  name_series = c(
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Média Nacional",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - São Paulo",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Rio de Janeiro",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Belo Horizonte",
    "Índice de Variação de Aluguéis Residenciais (IVAR) - Porto Alegre",
    "Sondagem da Construção – Nível de Utilização da Capacidade Instalada",
    "IE-CST Com ajuste Sazonal - Índice de Expectativas da Construção",
    "ISA-CST Com ajuste Sazonal - Índice da Situação Atual da Construção",
    "ICST Com ajuste Sazonal - Índice de Confiança da Construção",
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
    "Indicador", "Indicador", "Índice", "Índice", "Índice", "Percentual",
    "Percentual", "Percentual"
  )
)
