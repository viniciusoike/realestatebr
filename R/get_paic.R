# PAIC constants ---------------------------------------------------------------
#
# Pesquisa Anual da Indústria da Construção (PAIC), new series from 2024
# onward. See IBGE Nota técnica 01/2026.
# Legacy 2007-2023 tables are out of scope for the first release; do not
# join the two series or report growth rates across the 2023-2024 break.

paic_tables <- c(
  activity = 10463L,
  size = 10441L,
  state = 10442L
)

paic_geography_names <- c(
  "N1" = "brazil",
  "N2" = "region",
  "N3" = "state"
)

paic_state_codes <- c(
  "11",
  "12",
  "13",
  "14",
  "15",
  "16",
  "17",
  "21",
  "22",
  "23",
  "24",
  "25",
  "26",
  "27",
  "28",
  "29",
  "31",
  "32",
  "33",
  "35",
  "41",
  "42",
  "43",
  "50",
  "51",
  "52",
  "53"
)

# Retained variables, keyed by SIDRA variable ID. Table 10463 keeps all 89
# variables; table 10441 keeps the 16 level variables (share variables with
# IDs starting in "1000" are dropped); table 10442 keeps all 6 variables.
#
# `variable` holds English identifiers. They repeat across tables when the
# concept matches (e.g. "gross_revenue" is 1260 in `activity` and 1239 in
# `size`); `variable_id` always disambiguates. Variable 1245 in `state`
# equals 1236 plus 411 (construction plus development costs), so it gets its
# own identifier.
#
# `variable_name_pt` holds Portuguese labels pinned from live table metadata
# checked on 2026-09-27; unknown IDs fail validation instead of acquiring
# guessed labels. `unit` holds expected units: values publish in original
# units, including thousand reais ("Mil Reais") where specified by IBGE.
paic_variables <- tibble::tribble(
  ~variable_id , ~variable                            , ~variable_name_pt                                                                                                              , ~unit       ,
  "410"        , "firms"                              , "N\u00famero de empresas ativas"                                                                                               , "Unidades"  ,
  "631"        , "employment"                         , "Pessoal ocupado em 31/12"                                                                                                     , "Pessoas"   ,
  "673"        , "wages"                              , "Sal\u00e1rios, retiradas e outras remunera\u00e7\u00f5es"                                                                     , "Mil Reais" ,
  "1241"       , "construction_output"                , "Valor das incorpora\u00e7\u00f5es, obras e/ou servi\u00e7os da constru\u00e7\u00e3o"                                          , "Mil Reais" ,
  "838"        , "total_costs"                        , "Total de custos e despesas"                                                                                                   , "Mil Reais" ,
  "868"        , "personnel_costs"                    , "Gastos de pessoal"                                                                                                            , "Mil Reais" ,
  "1236"       , "construction_costs"                 , "Total de custos das obras e/ou servi\u00e7os da constru\u00e7\u00e3o"                                                         , "Mil Reais" ,
  "1237"       , "materials_consumption"              , "Consumo de materiais de constru\u00e7\u00e3o"                                                                                 , "Mil Reais" ,
  "411"        , "third_party_development_costs"      , "Total de custos de incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por terceiros"                                    , "Mil Reais" ,
  "412"        , "third_party_development_materials"  , "Custos de incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por terceiros - material de constru\u00e7\u00e3o"          , "Mil Reais" ,
  "1280"       , "other_costs"                        , "Outros custos e despesas - total"                                                                                             , "Mil Reais" ,
  "1260"       , "gross_revenue"                      , "Total da receita bruta"                                                                                                       , "Mil Reais" ,
  "1240"       , "net_revenue"                        , "Receita l\u00edquida"                                                                                                         , "Mil Reais" ,
  "637"        , "intermediate_consumption"           , "Consumo intermedi\u00e1rio - total"                                                                                           , "Mil Reais" ,
  "634"        , "gross_output"                       , "Valor bruto da produ\u00e7\u00e3o"                                                                                            , "Mil Reais" ,
  "1242"       , "value_added"                        , "Valor adicionado"                                                                                                             , "Mil Reais" ,
  "812"        , "avg_employment"                     , "N\u00famero m\u00e9dio de pessoal ocupado no ano"                                                                             , "Pessoas"   ,
  "1251"       , "construction_workers"               , "Pessoal ocupado assalariado ligado \u00e0 constru\u00e7\u00e3o"                                                               , "Pessoas"   ,
  "1252"       , "non_construction_workers"           , "Pessoal ocupado assalariado n\u00e3o-ligado \u00e0 constru\u00e7\u00e3o"                                                      , "Pessoas"   ,
  "1253"       , "owners_workers"                     , "Pessoal ocupado n\u00e3o-assalariado - propriet\u00e1rios e s\u00f3cios"                                                      , "Pessoas"   ,
  "1254"       , "construction_wages"                 , "Sal\u00e1rios, retiradas e outras remunera\u00e7\u00f5es - pessoal assalariado ligado \u00e0 constru\u00e7\u00e3o"            , "Mil Reais" ,
  "1255"       , "non_construction_wages"             , "Sal\u00e1rios, retiradas e outras remunera\u00e7\u00f5es - pessoal assalariado n\u00e3o-ligado \u00e0 constru\u00e7\u00e3o"   , "Mil Reais" ,
  "1256"       , "owners_wages"                       , "Sal\u00e1rios, retiradas e outras remunera\u00e7\u00f5es - pessoal n\u00e3o-assalariado - propriet\u00e1rios, s\u00f3cios"    , "Mil Reais" ,
  "664"        , "social_security"                    , "Contribui\u00e7\u00f5es para a previd\u00eancia social"                                                                       , "Mil Reais" ,
  "1257"       , "fgts"                               , "FGTS - Fundo de Garantia do Tempo de Servi\u00e7o"                                                                            , "Mil Reais" ,
  "1258"       , "private_pension"                    , "Contribui\u00e7\u00f5es para a previd\u00eancia privada"                                                                      , "Mil Reais" ,
  "1259"       , "severance"                          , "Indeniza\u00e7\u00f5es trabalhistas"                                                                                          , "Mil Reais" ,
  "667"        , "employee_benefits"                  , "Benef\u00edcios concedidos aos empregados"                                                                                    , "Mil Reais" ,
  "1261"       , "construction_works_executed"        , "Obras e/ou servi\u00e7os da constru\u00e7\u00e3o executados"                                                                  , "Mil Reais" ,
  "413"        , "development_gross_revenue"          , "Receita bruta - incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por outras empresas"                                 , "Mil Reais" ,
  "1284"       , "technical_services_revenue"         , "Receita bruta - servi\u00e7os t\u00e9cnicos de escrit\u00f3rio, de campo e de laborat\u00f3rio"                               , "Mil Reais" ,
  "1285"       , "materials_sales_revenue"            , "Receita bruta - venda de materiais de constru\u00e7\u00e3o e de demoli\u00e7\u00e3o"                                          , "Mil Reais" ,
  "1286"       , "property_resale_revenue"            , "Receita bruta - revenda de im\u00f3veis"                                                                                      , "Mil Reais" ,
  "1287"       , "labor_rental_revenue"               , "Receita bruta - loca\u00e7\u00e3o de m\u00e3o-de-obra"                                                                        , "Mil Reais" ,
  "642"        , "deductions"                         , "Dedu\u00e7\u00f5es"                                                                                                           , "Mil Reais" ,
  "1266"       , "rental_revenue"                     , "Receita do arrendamento e alugu\u00e9is de im\u00f3veis e equipamentos, etc."                                                 , "Mil Reais" ,
  "867"        , "financial_revenue"                  , "Receitas financeiras"                                                                                                         , "Mil Reais" ,
  "674"        , "other_operating_revenue"            , "Outras receitas operacionais"                                                                                                 , "Mil Reais" ,
  "646"        , "non_operating_revenue"              , "Receitas n\u00e3o-operacionais"                                                                                               , "Mil Reais" ,
  "1267"       , "abroad_revenue"                     , "Receitas de obras e/ou servi\u00e7os da constru\u00e7\u00e3o no exterior"                                                     , "Mil Reais" ,
  "1268"       , "fuel_consumption"                   , "Consumo de combust\u00edveis e lubrificantes"                                                                                 , "Mil Reais" ,
  "1269"       , "third_party_contracted_services"    , "Obras e/ou servi\u00e7os contratados a terceiros"                                                                             , "Mil Reais" ,
  "1270"       , "maintenance_services"               , "Servi\u00e7os de manuten\u00e7\u00e3o e repara\u00e7\u00e3o de m\u00e1quinas e equipamentos"                                  , "Mil Reais" ,
  "1271"       , "land_costs"                         , "Custos e despesas com terrenos"                                                                                               , "Mil Reais" ,
  "414"        , "third_party_contracted_works"       , "Custos de incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por terceiros - obras contratadas"                         , "Mil Reais" ,
  "415"        , "third_party_engineering_services"   , "Custos de incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por terceiros - servi\u00e7os de engenharia e arquitetura" , "Mil Reais" ,
  "416"        , "third_party_land"                   , "Custos de incorpora\u00e7\u00f5es de im\u00f3veis constru\u00eddos por terceiros - terrenos"                                  , "Mil Reais" ,
  "871"        , "property_rent"                      , "Alugu\u00e9is de im\u00f3veis"                                                                                                , "Mil Reais" ,
  "872"        , "equipment_rent"                     , "Alugu\u00e9is de m\u00e1quinas, equipamentos e ve\u00edculos"                                                                 , "Mil Reais" ,
  "1272"       , "depreciation"                       , "Deprecia\u00e7\u00e3o, amortiza\u00e7\u00e3o e exaust\u00e3o"                                                                 , "Mil Reais" ,
  "1273"       , "advertising"                        , "Despesas com propaganda"                                                                                                      , "Mil Reais" ,
  "1274"       , "freight"                            , "Fretes e carretos"                                                                                                            , "Mil Reais" ,
  "873"        , "taxes_fees"                         , "Impostos e taxas"                                                                                                             , "Mil Reais" ,
  "1275"       , "insurance"                          , "Pr\u00eamios e seguros"                                                                                                       , "Mil Reais" ,
  "1276"       , "monetary_variation"                 , "Varia\u00e7\u00f5es monet\u00e1rias passivas"                                                                                 , "Mil Reais" ,
  "1277"       , "financial_expenses"                 , "Despesas financeiras"                                                                                                         , "Mil Reais" ,
  "417"        , "resale_property_costs"              , "Custos de aquisi\u00e7\u00e3o de im\u00f3veis para revenda"                                                                   , "Mil Reais" ,
  "1278"       , "equity_losses"                      , "Resultados negativos em participa\u00e7\u00f5es societ\u00e1rias e em sociedades em cota de participa\u00e7\u00e3o"           , "Mil Reais" ,
  "1571"       , "commissions"                        , "Comiss\u00f5es pagas a terceiros"                                                                                             , "Mil Reais" ,
  "1279"       , "third_party_services"               , "Servi\u00e7os prestados por terceiros"                                                                                        , "Mil Reais" ,
  "875"        , "other_operating_costs"              , "Demais custos e despesas operacionais"                                                                                        , "Mil Reais" ,
  "661"        , "non_operating_expenses"             , "Despesas n\u00e3o-operacionais"                                                                                               , "Mil Reais" ,
  "1281"       , "construction_works_total"           , "Total do valor das obras e/ou servi\u00e7os da constru\u00e7\u00e3o"                                                          , "Mil Reais" ,
  "1282"       , "public_works"                       , "Valor das obras e/ou servi\u00e7os da constru\u00e7\u00e3o para entidades p\u00fablicas"                                      , "Mil Reais" ,
  "1283"       , "private_works"                      , "Valor das obras e/ou servi\u00e7os da constru\u00e7\u00e3o para entidades privadas"                                           , "Mil Reais" ,
  "1289"       , "fixed_assets_informants"            , "Ativo imobilizado - aquisi\u00e7\u00f5es de terceiros e produ\u00e7\u00e3o pr\u00f3pria - n\u00famero de informantes"         , "Unidades"  ,
  "1290"       , "fixed_assets_acquisitions"          , "Ativo imobilizado - total de aquisi\u00e7\u00f5es de terceiros e produ\u00e7\u00e3o pr\u00f3pria"                             , "Mil Reais" ,
  "1291"       , "fixed_assets_land_buildings"        , "Ativo imobilizado - aquisi\u00e7\u00f5es de terceiros e produ\u00e7\u00e3o pr\u00f3pria - terrenos e edifica\u00e7\u00f5es"   , "Mil Reais" ,
  "1292"       , "fixed_assets_machinery"             , "Ativo imobilizado - aquisi\u00e7\u00f5es de terceiros e produ\u00e7\u00e3o pr\u00f3pria - m\u00e1quinas e equipamentos"       , "Mil Reais" ,
  "1293"       , "fixed_assets_vehicles"              , "Ativo imobilizado - aquisi\u00e7\u00f5es de terceiros e produ\u00e7\u00e3o pr\u00f3pria - meios de transporte"                , "Mil Reais" ,
  "1294"       , "fixed_assets_other"                 , "Ativo imobilizado - outras aquisi\u00e7\u00f5es"                                                                              , "Mil Reais" ,
  "852"        , "improvements_informants"            , "Ativo imobilizado - melhorias - n\u00famero de informantes"                                                                   , "Unidades"  ,
  "1295"       , "improvements_total"                 , "Ativo imobilizado - total de melhorias"                                                                                       , "Mil Reais" ,
  "1296"       , "improvements_land_buildings"        , "Ativo imobilizado - melhorias - terrenos e edifica\u00e7\u00f5es"                                                             , "Mil Reais" ,
  "1297"       , "improvements_machinery"             , "Ativo imobilizado - melhorias - m\u00e1quinas e equipamentos"                                                                 , "Mil Reais" ,
  "1298"       , "improvements_vehicles"              , "Ativo imobilizado - melhorias - meios de transporte"                                                                          , "Mil Reais" ,
  "1299"       , "improvements_other"                 , "Ativo imobilizado - outras melhorias"                                                                                         , "Mil Reais" ,
  "854"        , "disposals_informants"               , "Ativo imobilizado - baixas - n\u00famero de informantes"                                                                      , "Unidades"  ,
  "1300"       , "disposals_total"                    , "Ativo imobilizado - total de baixas"                                                                                          , "Mil Reais" ,
  "1301"       , "disposals_land_buildings"           , "Ativo imobilizado - baixas - terrenos e edifica\u00e7\u00f5es"                                                                , "Mil Reais" ,
  "1302"       , "disposals_machinery"                , "Ativo imobilizado - baixas - m\u00e1quinas e equipamentos"                                                                    , "Mil Reais" ,
  "1303"       , "disposals_vehicles"                 , "Ativo imobilizado - baixas - meios de transporte"                                                                             , "Mil Reais" ,
  "1304"       , "disposals_other"                    , "Ativo imobilizado - outras baixas"                                                                                            , "Mil Reais" ,
  "1305"       , "materials_consumed_total"           , "Total dos principais produtos consumidos na constru\u00e7\u00e3o"                                                             , "Mil Reais" ,
  "1306"       , "asphalt_consumption"                , "Consumo de asfalto"                                                                                                           , "Mil Reais" ,
  "1307"       , "cement_consumption"                 , "Consumo de cimento"                                                                                                           , "Mil Reais" ,
  "1308"       , "concrete_consumption"               , "Consumo de concreto"                                                                                                          , "Mil Reais" ,
  "1309"       , "bricks_consumption"                 , "Consumo de tijolos"                                                                                                           , "Mil Reais" ,
  "1310"       , "rebar_consumption"                  , "Consumo de vergalh\u00f5es"                                                                                                   , "Mil Reais" ,
  "1235"       , "personnel_costs"                    , "Total de gastos de pessoal"                                                                                                   , "Mil Reais" ,
  "1238"       , "other_costs"                        , "Outros custos e despesas"                                                                                                     , "Mil Reais" ,
  "1239"       , "gross_revenue"                      , "Receita bruta total"                                                                                                          , "Mil Reais" ,
  "1245"       , "construction_and_development_costs" , "Custos das obras e/ou servi\u00e7os da constru\u00e7\u00e3o"                                                                  , "Mil Reais" ,
  "13807"      , "firms_hq"                           , "Empresas com 5 ou mais pessoas ocupadas - unidades da federa\u00e7\u00e3o de origem - sede"                                   , "Unidades"  ,
  "13808"      , "firms_active"                       , "Empresas com 5 ou mais pessoas ocupadas atuantes nas unidades da federa\u00e7\u00e3o"                                         , "Unidades"
)

# Explicit download lists. Table 10441 drops the 16 share variables
# ("percentual do total geral", IDs starting in "1000").
paic_activity_variables <- c(
  "410",
  "631",
  "673",
  "1241",
  "838",
  "868",
  "1236",
  "1237",
  "411",
  "412",
  "1280",
  "1260",
  "1240",
  "637",
  "634",
  "1242",
  "812",
  "1251",
  "1252",
  "1253",
  "1254",
  "1255",
  "1256",
  "664",
  "1257",
  "1258",
  "1259",
  "667",
  "1261",
  "413",
  "1284",
  "1285",
  "1286",
  "1287",
  "642",
  "1266",
  "867",
  "674",
  "646",
  "1267",
  "1268",
  "1269",
  "1270",
  "1271",
  "414",
  "415",
  "416",
  "871",
  "872",
  "1272",
  "1273",
  "1274",
  "873",
  "1275",
  "1276",
  "1277",
  "417",
  "1278",
  "1571",
  "1279",
  "875",
  "661",
  "1281",
  "1282",
  "1283",
  "1289",
  "1290",
  "1291",
  "1292",
  "1293",
  "1294",
  "852",
  "1295",
  "1296",
  "1297",
  "1298",
  "1299",
  "854",
  "1300",
  "1301",
  "1302",
  "1303",
  "1304",
  "1305",
  "1306",
  "1307",
  "1308",
  "1309",
  "1310"
)

paic_size_variables <- c(
  "410",
  "631",
  "838",
  "1235",
  "673",
  "1236",
  "1237",
  "411",
  "412",
  "1238",
  "1239",
  "1240",
  "1241",
  "637",
  "634",
  "1242"
)

paic_state_variables <- c(
  "13807",
  "13808",
  "631",
  "673",
  "1245",
  "1241"
)

# Classification 12296 crosswalk, keyed by category ID. Parsed once from
# live category labels (checked 2026-09-27); IBGE's `nivel` field does not
# track the CNAE level, so both dimensions come from this crosswalk at
# runtime. Labels drift; IDs do not.
paic_activity_categories <- tibble::tribble(
  ~category_id , ~size_band , ~activity_code ,
  "105185"     , "total"    , NA_character_  ,
  "8414"       , "1_4"      , NA_character_  ,
  "8415"       , "1_4"      , "41"           ,
  "8416"       , "1_4"      , "42"           ,
  "8417"       , "1_4"      , "43"           ,
  "105187"     , "5_29"     , NA_character_  ,
  "8418"       , "5_29"     , "41"           ,
  "8419"       , "5_29"     , "41.1"         ,
  "8475"       , "5_29"     , "41.2"         ,
  "8420"       , "5_29"     , "42"           ,
  "8421"       , "5_29"     , "42.1"         ,
  "8422"       , "5_29"     , "42.2"         ,
  "8423"       , "5_29"     , "42.9"         ,
  "8424"       , "5_29"     , "43"           ,
  "8425"       , "5_29"     , "43.1"         ,
  "8426"       , "5_29"     , "43.2"         ,
  "8427"       , "5_29"     , "43.3"         ,
  "8428"       , "5_29"     , "43.9"         ,
  "105194"     , "30_plus"  , NA_character_  ,
  "8432"       , "30_plus"  , "41"           ,
  "8430"       , "30_plus"  , "41.1"         ,
  "8431"       , "30_plus"  , "41.10"        ,
  "8433"       , "30_plus"  , "41.2"         ,
  "8476"       , "30_plus"  , "41.20"        ,
  "8434"       , "30_plus"  , "42"           ,
  "8435"       , "30_plus"  , "42.1"         ,
  "8436"       , "30_plus"  , "42.11"        ,
  "8437"       , "30_plus"  , "42.12"        ,
  "8438"       , "30_plus"  , "42.13"        ,
  "8439"       , "30_plus"  , "42.2"         ,
  "8440"       , "30_plus"  , "42.21"        ,
  "8441"       , "30_plus"  , "42.22"        ,
  "8442"       , "30_plus"  , "42.23"        ,
  "8443"       , "30_plus"  , "42.9"         ,
  "8444"       , "30_plus"  , "42.91"        ,
  "8445"       , "30_plus"  , "42.92"        ,
  "8446"       , "30_plus"  , "42.99"        ,
  "8447"       , "30_plus"  , "43"           ,
  "8448"       , "30_plus"  , "43.1"         ,
  "8449"       , "30_plus"  , "43.11"        ,
  "8450"       , "30_plus"  , "43.12"        ,
  "8451"       , "30_plus"  , "43.13"        ,
  "8452"       , "30_plus"  , "43.19"        ,
  "8453"       , "30_plus"  , "43.2"         ,
  "8454"       , "30_plus"  , "43.21"        ,
  "8455"       , "30_plus"  , "43.22"        ,
  "8456"       , "30_plus"  , "43.29"        ,
  "30084"      , "30_plus"  , "43.3"         ,
  "8458"       , "30_plus"  , "43.30"        ,
  "8459"       , "30_plus"  , "43.9"         ,
  "8460"       , "30_plus"  , "43.91"        ,
  "8461"       , "30_plus"  , "43.99"
)

# Classification 319 crosswalk, keyed by category ID.
paic_size_categories <- c(
  "104029" = "total",
  "111261" = "1_4",
  "104030" = "5_plus"
)

# Geography basis for table 10442, keyed by variable ID. Variable 13807
# counts firms by headquarters state ("origem - sede"); all other variables
# follow the work location. The PAIC 2024 publication (v. 34, June 2026,
# "Conceituação das variáveis investigadas") states that the regional block
# collects employment, wages, costs, and output by "Unidade da Federação de
# atuação da empresa" (checked 2026-09-27).
paic_state_geography_basis <- c(
  "13807" = "headquarters",
  "13808" = "work_location",
  "631" = "work_location",
  "673" = "work_location",
  "1245" = "work_location",
  "1241" = "work_location"
)

# Package-owned CNAE 2.0 lookup for divisions 41-43, keyed by code.
# IBGE category labels carry typos ("infraestrtutura") and inconsistent
# suffixes ("- total", "- subtotal"), so names come from here.
paic_cnae_names <- c(
  "41" = "Constru\u00e7\u00e3o de edif\u00edcios",
  "41.1" = "Incorpora\u00e7\u00e3o de empreendimentos imobili\u00e1rios",
  "41.10" = "Incorpora\u00e7\u00e3o de empreendimentos imobili\u00e1rios",
  "41.2" = "Constru\u00e7\u00e3o de edif\u00edcios",
  "41.20" = "Constru\u00e7\u00e3o de edif\u00edcios",
  "42" = "Obras de infraestrutura",
  "42.1" = "Constru\u00e7\u00e3o de rodovias, ferrovias, obras urbanas e obras-de-arte especiais",
  "42.11" = "Constru\u00e7\u00e3o de rodovias e ferrovias",
  "42.12" = "Constru\u00e7\u00e3o de obras de arte especiais",
  "42.13" = "Obras de urbaniza\u00e7\u00e3o - ruas, pra\u00e7as e cal\u00e7adas",
  "42.2" = "Obras de infraestrutura para energia el\u00e9trica, telecomunica\u00e7\u00f5es, \u00e1gua, esgoto e transporte por dutos",
  "42.21" = "Obras para gera\u00e7\u00e3o e distribui\u00e7\u00e3o de energia el\u00e9trica e para telecomunica\u00e7\u00f5es",
  "42.22" = "Constru\u00e7\u00e3o de redes de abastecimento de \u00e1gua, coleta de esgoto e constru\u00e7\u00f5es correlatas",
  "42.23" = "Constru\u00e7\u00e3o de redes de transportes por dutos, exceto para \u00e1gua e esgoto",
  "42.9" = "Constru\u00e7\u00e3o de outras obras de infraestrutura",
  "42.91" = "Obras portu\u00e1rias, mar\u00edtimas e fluviais",
  "42.92" = "Montagem de instala\u00e7\u00f5es industriais e de estruturas met\u00e1licas",
  "42.99" = "Obras de engenharia civil n\u00e3o especificadas anteriormente",
  "43" = "Servi\u00e7os especializados para constru\u00e7\u00e3o",
  "43.1" = "Demoli\u00e7\u00e3o e prepara\u00e7\u00e3o do terreno",
  "43.11" = "Demoli\u00e7\u00e3o e prepara\u00e7\u00e3o de canteiros de obras",
  "43.12" = "Perfura\u00e7\u00f5es e sondagens",
  "43.13" = "Obras de terraplenagem",
  "43.19" = "Servi\u00e7os de prepara\u00e7\u00e3o do terreno n\u00e3o especificados anteriormente",
  "43.2" = "Instala\u00e7\u00f5es el\u00e9tricas, hidr\u00e1ulicas e outras instala\u00e7\u00f5es em constru\u00e7\u00f5es",
  "43.21" = "Instala\u00e7\u00f5es el\u00e9tricas",
  "43.22" = "Instala\u00e7\u00f5es hidr\u00e1ulicas, de sistemas de ventila\u00e7\u00e3o e refrigera\u00e7\u00e3o",
  "43.29" = "Obras de instala\u00e7\u00f5es em constru\u00e7\u00f5es n\u00e3o especificadas anteriormente",
  "43.3" = "Obras de acabamento",
  "43.30" = "Obras de acabamento",
  "43.9" = "Outros servi\u00e7os especializados para constru\u00e7\u00e3o",
  "43.91" = "Obras de funda\u00e7\u00f5es",
  "43.99" = "Servi\u00e7os especializados para constru\u00e7\u00e3o n\u00e3o especificados anteriormente"
)

# Get PAIC data --------------------------------------------------------------

#' Get PAIC Construction Industry Data
#'
#' Downloads annual Pesquisa Anual da Indústria da Construção (PAIC) data
#' from IBGE for the new series starting in reference year 2024. The result
#' covers construction enterprises, employment, revenue, costs, and output.
#' Do not join this series with the 2007-2023 tables or report growth rates
#' across the 2023-2024 break (see IBGE Nota técnica 01/2026).
#'
#' @param table Character. One of `'activity'` (default), `'size'`,
#'   `'state'`, or `'all'`.
#' @param quiet Logical. If `TRUE`, suppresses progress messages.
#' @param max_retries Integer. Maximum retry attempts. Defaults to 3.
#'
#' @return Either a named `list` (when table is `'all'`) or a `tibble`
#'   (for specific tables).
#'
#' @source IBGE Pesquisa Anual da Indústria da Construção (PAIC), SIDRA
#'   tables 10463, 10441, and 10442
#' @keywords internal
get_paic <- function(
  table = "activity",
  quiet = FALSE,
  max_retries = 3L
) {
  valid_tables <- c("activity", "size", "state")
  validate_dataset_params(
    table,
    valid_tables,
    quiet,
    max_retries,
    allow_all = TRUE
  )

  cli_user("Downloading PAIC data from IBGE", quiet = quiet)

  tables <- if (table == "all") valid_tables else table
  out <- list()
  for (tbl in tables) {
    raw <- download_paic_table(tbl, quiet = quiet, max_retries = max_retries)
    cleaned <- switch(
      tbl,
      "activity" = clean_paic_activity(raw),
      "size" = clean_paic_size(raw),
      "state" = clean_paic_state(raw)
    )
    validate_paic(cleaned, tbl)
    out[[tbl]] <- attach_dataset_metadata(
      cleaned,
      source = "web",
      category = tbl,
      extra_info = list(sidra_table = unname(paic_tables[[tbl]]))
    )
  }

  if (table == "all") {
    cli_user("PAIC data retrieved: {length(out)} tables", quiet = quiet)
    return(out)
  }

  data <- out[[table]]
  cli_user("PAIC data retrieved: {nrow(data)} records", quiet = quiet)

  return(data)
}

download_paic_table <- function(table, quiet, max_retries) {
  aggregate <- unname(paic_tables[[table]])
  args <- switch(
    table,
    "activity" = list(
      variables = paic_activity_variables,
      localities = "N1[all]",
      classifications = "12296[all]"
    ),
    "size" = list(
      variables = paic_size_variables,
      localities = "N1[all]|N2[all]|N3[all]",
      classifications = "319[all]"
    ),
    "state" = list(
      variables = paic_state_variables,
      localities = "N1[all]|N2[all]|N3[all]",
      classifications = NULL
    )
  )

  raw <- download_ibge_aggregate(
    aggregate = aggregate,
    variables = args$variables,
    localities = args$localities,
    classifications = args$classifications,
    quiet = quiet,
    max_retries = max_retries
  )

  return(raw)
}

# Cleaning -------------------------------------------------------------------

clean_paic_activity <- function(raw) {
  base <- clean_paic_base(raw, expected_table = paic_tables[["activity"]])

  category_id <- paic_classification_codes(raw, 12296L)
  size_band <- paic_activity_categories$size_band[
    match(category_id, paic_activity_categories$category_id)
  ]
  activity_code <- paic_activity_categories$activity_code[
    match(category_id, paic_activity_categories$category_id)
  ]

  unknown <- unique(category_id[is.na(size_band)])
  if (length(unknown) > 0) {
    cli::cli_abort("Unknown PAIC activity category ID: {.val {unknown}}.")
  }

  activity_level <- paic_activity_level(activity_code)
  activity_name <- unname(paic_cnae_names[activity_code])
  missing_name <- !is.na(activity_code) & is.na(activity_name)
  if (any(missing_name)) {
    unknown <- unique(activity_code[missing_name])
    cli::cli_abort("Unknown PAIC CNAE code: {.val {unknown}}.")
  }

  dat <- tibble::tibble(
    year = base$year,
    source_table = base$source_table,
    geography_type = base$geography_type,
    geography_code = base$geography_code,
    geography_name = base$geography_name,
    size_band = size_band,
    activity_level = activity_level,
    activity_code = activity_code,
    activity_name = activity_name,
    division_code = substr(activity_code, 1, 2),
    group_code = paic_group_code(activity_code, activity_level),
    variable_id = base$variable_id,
    variable = base$variable,
    variable_name_pt = base$variable_name_pt,
    unit = base$unit,
    value = base$value,
    value_raw = base$value_raw,
    value_status = base$value_status
  )

  dat <- dplyr::arrange(
    dat,
    .data$year,
    .data$variable_id,
    .data$size_band,
    .data$activity_code
  )

  return(dat)
}

clean_paic_size <- function(raw) {
  raw <- raw[!grepl("^1000", raw$variable_id), ]
  base <- clean_paic_base(raw, expected_table = paic_tables[["size"]])

  # `clean_paic_base()` preserves input row order, so the classification
  # column aligns with the base rows by position.
  category_id <- paic_classification_codes(raw, 319L)
  size_band <- unname(paic_size_categories[category_id])

  unknown <- unique(category_id[is.na(size_band)])
  if (length(unknown) > 0) {
    cli::cli_abort("Unknown PAIC size category ID: {.val {unknown}}.")
  }

  dat <- tibble::tibble(
    year = base$year,
    source_table = base$source_table,
    geography_type = base$geography_type,
    geography_code = base$geography_code,
    geography_name = base$geography_name,
    size_band = size_band,
    variable_id = base$variable_id,
    variable = base$variable,
    variable_name_pt = base$variable_name_pt,
    unit = base$unit,
    value = base$value,
    value_raw = base$value_raw,
    value_status = base$value_status
  )

  # SIDRA publishes state figures for firms with five or more workers only;
  # "-" in the state total and 1-4 bands marks unpublished cells, not zeros.
  unpublished <- dat$geography_type == "state" & dat$size_band != "5_plus"
  dat <- dat[!unpublished, ]

  dat <- dplyr::arrange(
    dat,
    .data$year,
    .data$geography_type,
    .data$geography_code,
    .data$variable_id,
    .data$size_band
  )

  return(dat)
}

clean_paic_state <- function(raw) {
  base <- clean_paic_base(raw, expected_table = paic_tables[["state"]])

  geography_basis <- unname(paic_state_geography_basis[base$variable_id])
  if (anyNA(geography_basis)) {
    unknown <- unique(base$variable_id[is.na(geography_basis)])
    cli::cli_abort("Unknown PAIC state variable ID: {.val {unknown}}.")
  }

  dat <- tibble::tibble(
    year = base$year,
    source_table = base$source_table,
    geography_type = base$geography_type,
    geography_code = base$geography_code,
    geography_name = base$geography_name,
    geography_basis = geography_basis,
    variable_id = base$variable_id,
    variable = base$variable,
    variable_name_pt = base$variable_name_pt,
    unit = base$unit,
    value = base$value,
    value_raw = base$value_raw,
    value_status = base$value_status
  )

  dat <- dplyr::arrange(
    dat,
    .data$year,
    .data$geography_type,
    .data$geography_code,
    .data$variable_id
  )

  return(dat)
}

clean_paic_base <- function(raw, expected_table) {
  if (nrow(raw) == 0) {
    cli::cli_abort(
      "PAIC response for SIDRA table {.val {expected_table}} is empty."
    )
  }
  if (!identical(unique(raw$aggregate_id), as.character(expected_table))) {
    cli::cli_abort(
      "PAIC response is not from SIDRA table {.val {expected_table}}."
    )
  }

  variable_row <- match(raw$variable_id, paic_variables$variable_id)
  if (anyNA(variable_row)) {
    unknown <- unique(raw$variable_id[is.na(variable_row)])
    cli::cli_abort("Unknown PAIC variable ID: {.val {unknown}}.")
  }
  variable_info <- paic_variables[variable_row, ]

  expected_unit <- variable_info$unit
  bad_unit <- !is.na(raw$unit) &
    raw$unit != "" &
    !is.na(expected_unit) &
    raw$unit != expected_unit
  if (any(bad_unit)) {
    unknown <- unique(raw$variable_id[bad_unit])
    cli::cli_abort("Unexpected unit for PAIC variable ID: {.val {unknown}}.")
  }
  if (anyNA(raw$unit) || any(raw$unit == "")) {
    unknown <- unique(raw$variable_id[is.na(raw$unit) | raw$unit == ""])
    cli::cli_abort(
      "PAIC data contains observations without a unit: {.val {unknown}}."
    )
  }

  geography_type <- unname(paic_geography_names[raw$geography_level])
  if (anyNA(geography_type)) {
    unknown <- unique(raw$geography_level[is.na(geography_type)])
    cli::cli_abort("Unknown PAIC geography level: {.val {unknown}}.")
  }
  if (anyNA(raw$geography_code) || any(raw$geography_code == "")) {
    cli::cli_abort("PAIC data contains observations without a geography code.")
  }

  year <- suppressWarnings(as.integer(raw$period))
  if (anyNA(year)) {
    cli::cli_abort("PAIC data contains observations without a reference year.")
  }

  dat <- tibble::tibble(
    year = year,
    source_table = as.integer(expected_table),
    geography_type = geography_type,
    geography_code = raw$geography_code,
    geography_name = raw$geography_name,
    variable_id = raw$variable_id,
    variable = variable_info$variable,
    variable_name_pt = variable_info$variable_name_pt,
    unit = raw$unit,
    value = raw$value,
    value_raw = raw$value_raw,
    value_status = paic_value_status(raw$value_raw)
  )

  return(dat)
}

paic_classification_codes <- function(
  raw,
  classification_id,
  call = rlang::caller_env()
) {
  column <- paste0("classification_", classification_id, "_code")
  if (!column %in% names(raw)) {
    cli::cli_abort(
      "PAIC response lacks classification {.val {classification_id}}.",
      call = call
    )
  }

  return(raw[[column]])
}

paic_value_status <- function(value_raw) {
  value_raw <- trimws(value_raw)
  status <- rep("observed", length(value_raw))
  status[is.na(value_raw) | value_raw == ""] <- "missing"
  status[!is.na(value_raw) & value_raw == "-"] <- "zero"
  status[!is.na(value_raw) & value_raw == ".."] <- "not_applicable"
  status[!is.na(value_raw) & value_raw == "..."] <- "not_available"
  status[!is.na(value_raw) & value_raw == "X"] <- "suppressed"

  return(status)
}

paic_activity_level <- function(activity_code) {
  digits <- nchar(gsub("\\.", "", activity_code))
  level <- dplyr::case_when(
    is.na(activity_code) ~ "total",
    digits == 2L ~ "division",
    digits == 3L ~ "group",
    digits == 4L ~ "class",
    .default = NA_character_
  )
  if (anyNA(level)) {
    unknown <- unique(activity_code[is.na(level)])
    cli::cli_abort("Unknown PAIC CNAE code: {.val {unknown}}.")
  }

  return(level)
}

paic_group_code <- function(activity_code, activity_level) {
  group_code <- rep(NA_character_, length(activity_code))
  is_group_or_class <- !is.na(activity_level) &
    activity_level %in% c("group", "class")
  group_code[is_group_or_class] <- sub(
    "^(\\d+\\.\\d).*$",
    "\\1",
    activity_code[is_group_or_class]
  )

  return(group_code)
}

# Validation -----------------------------------------------------------------

validate_paic <- function(dat, table) {
  switch(
    table,
    "activity" = validate_paic_activity(dat),
    "size" = validate_paic_size(dat),
    "state" = validate_paic_state(dat)
  )
}

validate_paic_activity <- function(dat) {
  validate_paic_common(dat, "activity")

  # Only "Total das empresas" covers all firms; it must equal the sum of the
  # three size-band subtotals. The tolerance absorbs IBGE rounding.
  totals <- dat[dat$activity_level == "total", ]
  check <- dplyr::summarise(
    totals,
    gap = abs(
      sum(.data$value[.data$size_band == "total"]) -
        sum(.data$value[.data$size_band != "total"])
    ),
    .by = c("year", "variable_id")
  )
  bad <- unique(check$variable_id[!is.na(check$gap) & check$gap > 1])
  if (length(bad) > 0) {
    cli::cli_abort(
      "PAIC activity size bands do not sum to the all-firm total for variable{?s} {.val {bad}}."
    )
  }

  return(invisible(TRUE))
}

validate_paic_size <- function(dat) {
  validate_paic_common(dat, "size")

  return(invisible(TRUE))
}

validate_paic_state <- function(dat) {
  validate_paic_common(dat, "state")

  basis <- unique(dat$geography_basis[dat$variable_id == "13807"])
  if (!identical(basis, "headquarters")) {
    cli::cli_abort("PAIC variable 13807 must use the headquarters basis.")
  }
  other_basis <- unique(dat$geography_basis[dat$variable_id != "13807"])
  if (!all(other_basis == "work_location")) {
    cli::cli_abort(
      "PAIC state variables other than 13807 must use the work-location basis."
    )
  }

  return(invisible(TRUE))
}

# Checks shared by all PAIC tables: required columns, unique keys, units,
# and exact coverage of the pinned crosswalk for every year present.
validate_paic_common <- function(dat, table, call = rlang::caller_env()) {
  expected <- paic_expected_keys(table)
  keys <- c("year", names(expected))

  validate_dataset(
    dat,
    dataset_name = paste0("paic_", table),
    required_cols = c(keys, "source_table", "variable", "unit", "value"),
    check_dates = FALSE
  )

  check <- dplyr::summarise(dat, n = dplyr::n(), .by = dplyr::all_of(keys))
  if (any(check$n > 1)) {
    cli::cli_abort(
      "PAIC {table} data contains duplicate observation keys.",
      call = call
    )
  }
  if (anyNA(dat$unit) || any(dat$unit == "")) {
    cli::cli_abort(
      "PAIC {table} data contains observations without a unit.",
      call = call
    )
  }

  expected <- tidyr::expand_grid(year = unique(dat$year), expected)
  missing <- dplyr::anti_join(expected, dat, by = keys)
  if (nrow(missing) > 0) {
    cli::cli_abort(
      c(
        "PAIC {table} data is missing {nrow(missing)} expected observation{?s}.",
        "i" = "First missing key: {paic_format_key(missing[1, ])}."
      ),
      call = call
    )
  }
  unexpected <- dplyr::anti_join(dat[keys], expected, by = keys)
  if (nrow(unexpected) > 0) {
    cli::cli_abort(
      c(
        "PAIC {table} data contains {nrow(unexpected)} unexpected observation{?s}.",
        "i" = "First unexpected key: {paic_format_key(unexpected[1, ])}."
      ),
      call = call
    )
  }

  return(invisible(TRUE))
}

# Expected observation keys per year, from the pinned crosswalks.
paic_expected_keys <- function(table) {
  geographies <- tibble::tibble(
    geography_type = c("brazil", rep("region", 5), rep("state", 27)),
    geography_code = c("1", as.character(1:5), paic_state_codes)
  )

  keys <- switch(
    table,
    "activity" = tidyr::expand_grid(
      geography_type = "brazil",
      geography_code = "1",
      variable_id = paic_activity_variables,
      paic_activity_categories[c("size_band", "activity_code")]
    ),
    # State rows cover firms with five or more workers only.
    "size" = tidyr::expand_grid(
      geographies,
      variable_id = paic_size_variables,
      size_band = unname(paic_size_categories)
    ) |>
      dplyr::filter(
        .data$geography_type != "state" | .data$size_band == "5_plus"
      ),
    "state" = tidyr::expand_grid(
      geographies,
      variable_id = paic_state_variables
    )
  )

  return(keys)
}

paic_format_key <- function(row) {
  return(paste(names(row), unlist(row), sep = " = ", collapse = ", "))
}
