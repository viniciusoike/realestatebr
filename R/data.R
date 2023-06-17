#' Brazilian Central Bank Series Metadata
#'
#' A table with metadata that supports the `get_bcb_series()` function.
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

#' World Health Organization TB data
#'
#' A subset of data from the World Health Organization Global Tuberculosis
#' Report ...
#'
#' @format ## `who`
#' A data frame with 7,240 rows and 60 columns:
#' \describe{
#'   \item{country}{Country name}
#'   \item{iso2, iso3}{2 & 3 letter ISO country codes}
#'   \item{year}{Year}
#'   ...
#' }
#' @source <https://www.who.int/teams/global-tuberculosis-programme/data>
"dim_city"

#' World Health Organization TB data
#'
#' A subset of data from the World Health Organization Global Tuberculosis
#' Report ...
#'
#' @format ## `who`
#' A data frame with 7,240 rows and 60 columns:
#' \describe{
#'   \item{country}{Country name}
#'   \item{iso2, iso3}{2 & 3 letter ISO country codes}
#'   \item{year}{Year}
#'   ...
#' }
#' @source <https://www.who.int/teams/global-tuberculosis-programme/data>
"main_cities"

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
