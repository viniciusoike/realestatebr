#' Get the IRE Index
#'
#' Imports the Real Estate Index from NRE-Poli (USP)
#'
#' @details
#' The Real Estate Index (IRE) tracks the average stock price of real estate
#' companies in Brazil. The Index is maintained by the Real Estate Research
#' Group by the Polytechnich School of the University of São Paulo (NRE-Poli-USP).
#'
#' The values are indexed (100 = May/2006). Check `return` for a definition of each
#' column.
#'
#' @inheritParams get_secovi
#'
#'
#' @return A tibble with 8 columns where:
#' * `ire` is the IRE Index.
#' * `ire_r50_plus` is the IRE Index of the top 50% companies.
#' * `ire_r50_minus` is the IRE Index of the bottom 50% companies.
#' * `ire_bi` is the IRE-BI Index (non-residential).
#' * `ibov` is the Ibovespa Index.
#' * `ibov_points` is the Ibovespa Index in points.
#' * `ire_ibov` is the ratio of the IRE Index and the Ibovespa Index.
#' @export
#' @source Original series and methodology available at [https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html](https://www.realestate.br/site/conteudo/pagina/1,84+Indice_IRE.html).
#' @examples
#' # Import the IRE Index
#' ire <- get_nre_ire()
get_nre_ire <- function(cached = FALSE) {

  if (cached) {
    ire <- import_cached("ire")
  }

  return(ire)

}
