## code to prepare `DATASET` dataset goes here

main_cities <- tidyr::tribble(

  ~code_muni,      ~name_muni,          ~abbrev_muni,
  #|---------|-----------------------|-------------------|
  1100205,	  "Porto Velho",              "pvo",
  1200401,	  "Rio Branco",	              "rbo",
  1302603,	  "Manaus",                   "man",
  1400100,	  "Boa Vista",                "bva",
  1500800,	  "Ananindeua",               "ana",
  1501402,	  "Belém",                    "bel",
  1502400,	  "Castanhal",                "cas",
  1504208,	  "Marabá",                   "mar",
  1600303,	  "Macapá",                   "mcp",
  1721000,	  "Palmas",                   "pal",
  2111300,	  "São Luís",                 "sls",
  2211001,	  "Teresina",                 "ter",
  2304400,	  "Fortaleza",                "for",
  2408102,	  "Natal",                    "nat",
  2507507,	  "João Pessoa",              "jpa",
  2611606,	  "Recife",                   "rec",
  2704302,	  "Maceió",                   "mac",
  2927408,	  "Salvador",                 "sal",
  3106200,	  "Belo Horizonte",           "bhe",
  3118601,	  "Contagem",                 "con",
  3122306,	  "Divinópolis",              "div",
  3136702,	  "Juiz de Fora",	            "jfa",
  3170206,	  "Uberlândia",               "ube",
  3205309,	  "Vitória",                  "vit",
  3301702,	  "Duque de Caxias",          "dqc",
  3303302,	  "Niterói",                  "nit",
  3303500,	  "Nova Iguaçu",              "nvi",
  3303906,	  "Petrópolis	",              "pet",
  3304557,	  "Rio de Janeiro",           "rio",
  3304904,	  "São Gonçalo",              "sgo",
  3505708,	  "Barueri",                  "bar",
  3509502,	  "Campinas",                 "cam",
  3513801,	  "Diadema",                  "dia",
  3515004,	  "Embu das Artes",           "eas",
  3518701,	  "Guarujá",                  "grj",
  3518800,	  "Guarulhos",                "gua",
  3525904,	  "Jundiaí",                  "jun",
  3530607,	  "Mogi das Cruzes",          "mog",
  3534401,	  "Osasco",                   "osa",
  3541000,	  "Praia Grande",             "pge",
  3543402,	  "Ribeirão Preto",           "rpo",
  3547809,	  "Santo André",              "sae",
  3548500,	  "Santos",                   "san",
  3548708,	  "São Bernardo do Campo",	  "sbc",
  3549805,	  "São José do Rio Preto",	  "srp",
  3549904,	  "São José dos Campos",      "sjc",
  3550308,	  "São Paulo",                "spo",
  3551009,	  "São Vicente",              "sve",
  3552205,	  "Sorocaba",                 "sor",
  4104808,	  "Cascavel",                 "csc",
  4106902,	  "Curitiba",                 "cur",
  4113700,	  "Londrina",                 "lon",
  4115200,	  "Maringá",                  "mga",
  4119905,	  "Ponta Grossa",             "pga",
  4202404,	  "Blumenau",                 "blu",
  4204202,	  "Chapecó",                  "cha",
  4205407,	  "Florianópolis",            "flo",
  4208203,	  "Itajaí",                   "ita",
  4209102,	  "Joinville",                "joi",
  4304606,	  "Canoas",                   "can",
  4305108,	  "Caxias do Sul",            "cxs",
  4309209,	  "Gravataí",                 "gra",
  4313409,	  "Novo Hamburgo",            "nho",
  4314100,	  "Passo Fundo",              "pfo",
  4314407,	  "Pelotas",                  "pel",
  4314902,	  "Porto Alegre",             "poa",
  4316907,	  "Santa Maria",              "sma",
  4318705,	  "São Leopoldo",             "slo",
  5002704,	  "Campo Grande",             "cge",
  5103403,	  "Cuiabá",                   "cui",
  5208707,	  "Goiânia",                  "goi",
  5300108,	  "Brasília",                 "bsb"
)

code_main_cities <- unique(main_cities$code_muni)

# Import city shapefile with official IBGE identifiers
dim_city <- geobr::read_municipality(year = 2020)
# Drop geometry
dim_city <- sf::st_drop_geometry(dim_city)
dim_city <- tibble::as_tibble(dim_city)
# Convert code_state to numeric
dim_city <- dplyr::mutate(dim_city, code_state = as.numeric(code_state))

# Create a simplified name for cities
# Obs: can't use janitor::make_clean_names because of non-unique city names
dim_city <- dim_city |>
  dplyr::mutate(
    name_simplified = stringi::stri_trans_general(name_muni, "latin-ascii"),
    name_simplified = stringr::str_to_lower(name_simplified),
    name_simplified = stringr::str_replace_all(name_simplified, " ", "_")
  )

usethis::use_data(main_cities, overwrite = TRUE)
usethis::use_data(dim_city, overwrite = TRUE)

source("data-raw/abecip_cgi.R")
source("data-raw/fgv_clean.R")

usethis::use_data(abecip_cgi, fgv_data, internal = TRUE, overwrite = TRUE)
