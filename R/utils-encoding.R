#' Character Encoding Utilities
#'
#' Internal utilities for consistent handling of Portuguese characters.
#' The package uses UTF-8 encoding (declared in DESCRIPTION) throughout.
#'
#' @keywords internal
#' @name encoding-utils
NULL

#' Character mappings for consistent encoding
#'
#' Maps ASCII-key identifiers to their UTF-8 Portuguese equivalents.
#' Keys are kept as plain ASCII for easy programmatic lookup; values
#' are UTF-8 strings as supported by \code{Encoding: UTF-8} in DESCRIPTION.
#'
#' @keywords internal
.ENCODING_MAP <- list(
  # ASCII keys \u2192 UTF-8 values
  "producao" = "produ\u00e7\u00e3o",
  "exportacao" = "exporta\u00e7\u00e3o",
  "aco" = "a\u00e7o",
  "preco" = "pre\u00e7o",
  "sao" = "S\u00e3o",
  "brasilia" = "Bras\u00edlia",
  "goiania" = "Goi\u00e2nia",
  "indice" = "\u00cdndice",
  "espirito" = "Esp\u00edrito",
  "regiao" = "REGI\u00c3O",
  "federacao" = "Federa\u00e7\u00e3o",
  "imoveis" = "Im\u00f3veis",
  "seminario" = "Semin\u00e1rio"
)

#' Test function to verify encoding patterns work correctly
#'
#' @keywords internal
test_encoding_patterns <- function() {
  # Test CBIC file patterns
  test_string_1 <- "produ\u00e7\u00e3o e consumo de exporta\u00e7\u00e3o"
  pattern_1 <- "produ\u00e7\u00e3o.*consumo.*exporta\u00e7\u00e3o"

  # Test city matching
  city_1 <- "S\u00e3o Paulo"
  city_2 <- "S\u00e3o Paulo"

  # Test region pattern
  region_test <- "REGI\u00c3O NORDESTE"
  region_pattern <- "^REGI\u00c3O"

  # Verify patterns work
  tests <- list(
    cbic_pattern = grepl(pattern_1, test_string_1),
    city_equivalence = city_1 == city_2,
    region_pattern = grepl(region_pattern, region_test)
  )

  return(tests)
}
