#' Character Encoding Utilities
#'
#' Internal utilities for consistent handling of Portuguese characters
#' using Unicode escapes to maintain CRAN compliance.
#'
#' @keywords internal
#' @name encoding-utils
NULL

#' Character mappings for consistent encoding
#'
#' This list contains Unicode escape sequences for Portuguese characters
#' commonly used in Brazilian data sources. Using Unicode escapes ensures
#' CRAN compliance while maintaining correct character representation.
#'
#' @keywords internal
.ENCODING_MAP <- list(
  # Portuguese characters with diacritics (using ASCII keys for CRAN compliance)
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

#' Test function to verify Unicode escapes work correctly
#'
#' @keywords internal
test_encoding_patterns <- function() {
  # Test CBIC file patterns
  test_string_1 <- "produ\u00e7\u00e3o e consumo de exporta\u00e7\u00e3o"
  pattern_1 <- "produ\u00e7\u00e3o.*consumo.*exporta\u00e7\u00e3o"

  # Test city matching
  city_1 <- "S\u00e3o Paulo"
  city_2 <- "S\u00e3o Paulo"  # Both should be Unicode escaped

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