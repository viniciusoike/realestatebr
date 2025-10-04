#' Brazilian Central Bank Series Metadata
#'
#' A table with metadata for BCB economic series. Use with `get_dataset("bcb_series")`.
#'
#' @format ## `bcb_metadata`
#' A data frame with 140 rows and 10 columns:
#' \describe{
#'   \item{code_bcb}{Numeric code identifying the series.}
#'   \item{bcb_category}{Category of the series.}
#'   \item{name_simplified}{Simplified name of the series.}
#'   \item{name_pt}{Full name of the series in Portuguese.}
#'   \item{name}{Full name of the series in English.}
#'   \item{unit}{Unit of the series.}
#'   \item{frequency}{Frequency of the series.}
#'   \item{first_value}{Date of the first available observation.}
#'   \item{last_value}{Date of the last available observation.}
#'   \item{source}{Source of the series.}
#' }
#' @source <https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries>
"bcb_metadata"


#' Brazilian city identifier table
#'
#' A table with official IBGE identifiers for all Brazilian cities.
#'
#' A `tibble` with 5,570 rows and 8 columns:
#' \describe{
#'   \item{code_muni}{7-digit IBGE code identifying the city.}
#'   \item{name_muni}{Name of the city.}
#'   \item{code_state}{2-digit IBGE code identifying the state.}
#'   \item{name_state}{Name of the state.}
#'   \item{code_region}{1-digit IBGE code identifying the region}
#'   \item{name_region}{Name of the region}
#'   \item{name_simplified}{Simplified version of the city name for easier subsetting.}
#' }
#' @source <IBGE ...>
"dim_city"

#' Real Estate Players listed on B3
#'
#' List of mian Brazilian real estate players listed on B3.
#'
#' @format ## `b3_real_estate`
#' A tibble with 38 rows and 3 columns:
#' \describe{
#'   \item{symbol}{Stock ticker.}
#'   \item{name}{Full company name.}
#'   \item{name_short}{A shorter version of the company name.}
#' }
#' @source <https://www.b3.com.br/pt_br/produtos-e-servicos/negociacao/renda-variavel/empresas-listadas.htm>
"b3_real_estate"
