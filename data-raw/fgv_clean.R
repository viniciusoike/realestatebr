# FGV Data is currently not acessible via API
# The temporary solution is to download the data from
# https://extra-ibre.fgv.br/IBRE/sitefgvdados/consulta.aspx

# Roteiro para update manual:

# 1. Ir para https://autenticacao-ibre.fgv.br/ProdutosDigitais/
# 2. Fazer login
# 3. Inserir as séries: IVAR, Sondagem, INCC, nesta ordem.

# OBS: revisar séries e ordem das séries para facilitar o processo.

# fmt: skip
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

fgv_data <- readr::read_delim(
  "data-raw/xgdvConsulta.csv",
  delim = ";",
  locale = readr::locale(decimal_mark = ",", encoding = "ISO-8859-1"),
  na = " - ",
  col_types = "cddddddddddddddd"
)

fgv_data <- fgv_data |>
  dplyr::rename(date = Data) |>
  dplyr::mutate(date = readr::parse_date(date, format = "%m/%Y")) |>
  tidyr::pivot_longer(-date, names_to = "name_series")

fgv_data <- fgv_data |>
  dplyr::mutate(
    code_series = stringr::str_extract(name_series, "(?<=\\()\\d{7}(?=\\))"),
    code_series = as.numeric(code_series)
  ) |>
  dplyr::select(-name_series)

# fmt: skip
fgv_data <- fgv_data |>
  dplyr::left_join(fgv_dict, by = "code_series") |>
  dplyr::left_join(fgv_key, by = "code_series") |>
  dplyr::select(
    date, name_simplified, value, name_series, code_series, unit, source
  ) |>
  dplyr::filter(!is.na(value))

# fgv_dict <- readxl::read_excel(
#   path = "data-raw/xgvxConsulta.xls",
#   range = "A11:G20"
# )
#
# fgv_dict <- fgv_dict |>
#   janitor::clean_names() |>
#   dplyr::select(
#     id_series = serie,
#     name_series = titulo,
#     code_series = codigo,
#     source = fonte,
#     unit = unidade
#   ) |>
#   dplyr::mutate(
#     id_series = as.integer(id_series),
#     code_series = as.numeric(code_series)
#   )
#
# fgv_key <- tibble::tribble(
#   ~code_series,      ~name_simplified,
#        1463201,         "ivar_brazil",
#        1463202,      "ivar_sao_paulo",
#        1463203, "ivar_rio_de_janeiro",
#        1463204, "ivar_belo_horizonte",
#        1463205,   "ivar_porto_alegre",
#        1428409,                "nuci",
#        1416233,              "ie_cst",
#        1416234,             "isa_cst",
#        1416232,              "ic_cst"
# )
#
# get_range("data-raw/xgvxConsulta.xls")
#
# fgv_data <- readxl::read_excel(
#   path = "data-raw/xgvxConsulta.xls",
#   range = "A22:J175"
# )
#
# fgv_data <- fgv_data |>
#   dplyr::rename(date = Data) |>
#   dplyr::mutate(date = readr::parse_date(date, format = "%m/%Y")) |>
#   tidyr::pivot_longer(
#     -date,
#     names_to = "id_series",
#     values_transform = as.numeric
#     ) |>
#   dplyr::mutate(id_series = as.integer(id_series)) |>
#   dplyr::left_join(fgv_dict, by = "id_series") |>
#   dplyr::left_join(fgv_key, by = "code_series") |>
#   dplyr::select(
#     date, name_simplified, value, name_series, code_series, unit, source
#   )
