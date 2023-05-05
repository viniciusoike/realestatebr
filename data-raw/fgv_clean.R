# FGV Data is currently not acessible via API
# The temporary solution is to download the data from
# https://extra-ibre.fgv.br/IBRE/sitefgvdados/consulta.aspx
fgv_dict <- readxl::read_excel(
  path = "data-raw/xgvxConsulta.xls",
  range = "A11:G20"
)

fgv_dict <- fgv_dict |>
  janitor::clean_names() |>
  dplyr::select(
    id_series = serie,
    name_series = titulo,
    code_series = codigo,
    source = fonte,
    unit = unidade
  ) |>
  dplyr::mutate(
    id_series = as.integer(id_series),
    code_series = as.numeric(code_series)
  )

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
       1416232,              "ic_cst"
)

fgv_data <- readxl::read_excel(
  path = "data-raw/xgvxConsulta.xls",
  range = "A22:J175"
)

fgv_data <- fgv_data |>
  dplyr::rename(date = Data) |>
  dplyr::mutate(date = readr::parse_date(date, format = "%m/%Y")) |>
  tidyr::pivot_longer(
    -date,
    names_to = "id_series",
    values_transform = as.numeric
    ) |>
  dplyr::mutate(id_series = as.integer(id_series)) |>
  dplyr::left_join(fgv_dict, by = "id_series") |>
  dplyr::left_join(fgv_key, by = "code_series") |>
  dplyr::select(
    date, name_simplified, value, name_series, code_series, unit, source
  )

usethis::use_data(fgv_data, internal = TRUE, overwrite = TRUE)

