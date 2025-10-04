#' Translation Utilities for Brazilian Real Estate Data
#'
#' This file contains functions for translating Portuguese column names and values
#' to English following geobr package patterns and real estate domain conventions.

#' Translate Dataset Column Names and Values
#'
#' Apply standard Portuguese to English translations for a given dataset.
#' Follows geobr package conventions and real estate domain standards.
#'
#' @param data Dataset (tibble or list of tibbles)
#' @param dataset_name Name of the dataset for context-specific translations
#' @return Translated dataset with English column names and standardized values
#' @keywords internal
translate_dataset <- function(data, dataset_name) {
  
  if (is.list(data) && !inherits(data, "data.frame")) {
    # Handle list of tibbles (e.g., ABECIP, ABRAINC)
    data <- purrr::map(data, translate_tibble, dataset_name = dataset_name)
  } else if (inherits(data, "data.frame")) {
    # Handle single tibble
    data <- translate_tibble(data, dataset_name)
  }
  
  return(data)
}

#' Translate Individual Tibble
#'
#' @param df Data frame to translate
#' @param dataset_name Dataset name for context
#' @return Translated data frame
#' @keywords internal
translate_tibble <- function(df, dataset_name) {
  
  if (!inherits(df, "data.frame") || nrow(df) == 0) {
    return(df)
  }
  
  # Translate column names
  old_names <- names(df)
  new_names <- translate_column_names(old_names, dataset_name)
  names(df) <- new_names
  
  # Translate values in specific columns
  df <- translate_column_values(df, dataset_name)
  
  return(df)
}

#' Translate Column Names
#'
#' @param column_names Vector of column names to translate
#' @param dataset_name Dataset name for context-specific translations
#' @return Vector of translated column names
#' @keywords internal
translate_column_names <- function(column_names, dataset_name) {
  
  # Standard translations (following geobr patterns)
  standard_translations <- list(
    # Geographic
    "estado" = "state",
    "uf" = "state", 
    "sigla_uf" = "state_abbrev",
    "nome_uf" = "state_name",
    "municipio" = "municipality",
    "codigo_municipio" = "municipality_code",
    "nome_municipio" = "municipality_name",
    "regiao" = "region",
    "codigo_regiao" = "region_code",
    "nome_regiao" = "region_name",
    "localidade" = "location",
    
    # Time
    "ano" = "year",
    "mes" = "month",
    "trimestre" = "quarter",
    "data" = "date",
    "periodo" = "period",
    "semestre" = "semester",
    
    # Common values
    "valor" = "value",
    "preco" = "price",
    "indice" = "index",
    "taxa" = "rate",
    "percentual" = "percentage",
    "variacao" = "variation",
    "crescimento" = "growth",
    "quantidade" = "quantity",
    "numero" = "number",
    "total" = "total",
    
    # Real estate specific
    "lancamentos" = "launches",
    "vendas" = "sales", 
    "unidades" = "units",
    "imoveis" = "properties",
    "financiamento" = "financing",
    "credito" = "credit",
    "emprestimo" = "loan",
    "aluguel" = "rent",
    "locacao" = "rental",
    "compra" = "purchase",
    "venda" = "sale",
    "construcao" = "construction",
    "aquisicao" = "acquisition",
    "habitacao" = "housing",
    "residencial" = "residential",
    "comercial" = "commercial",
    "metro_quadrado" = "square_meter",
    "area" = "area",
    "tipologia" = "property_type",
    "categoria" = "category",
    
    # Financial
    "moeda" = "currency",
    "real" = "brl",
    "nominal" = "nominal",
    "deflacionado" = "real_value",
    "corrigido" = "adjusted",
    "juros" = "interest",
    "prazo" = "term",
    "inadimplencia" = "default",
    "inadimplente" = "defaulted",
    
    # Construction materials (CBIC)
    "cimento" = "cement",
    "aco" = "steel",
    "producao" = "production",
    "consumo" = "consumption",
    "exportacao" = "export",
    "importacao" = "import",
    "tonelada" = "ton",
    "quilograma" = "kg"
  )
  
  # Dataset-specific translations
  dataset_translations <- get_dataset_specific_translations(dataset_name)
  
  # Combine translations (dataset-specific takes precedence)
  all_translations <- c(dataset_translations, standard_translations)
  
  # Apply translations
  translated_names <- purrr::map_chr(column_names, function(name) {
    # Convert to lowercase for matching
    name_lower <- tolower(name)
    
    # Check for exact match
    if (name_lower %in% names(all_translations)) {
      return(all_translations[[name_lower]])
    }
    
    # Check for partial matches (e.g., "valor_total" -> "total_value")
    for (pt_term in names(all_translations)) {
      if (grepl(pt_term, name_lower, fixed = TRUE)) {
        en_term <- all_translations[[pt_term]]
        # Replace the Portuguese term with English
        new_name <- gsub(pt_term, en_term, name_lower, fixed = TRUE)
        return(new_name)
      }
    }
    
    # If no translation found, clean up the name
    clean_name <- clean_column_name(name)
    return(clean_name)
  })
  
  return(translated_names)
}

#' Get Dataset-Specific Translations
#'
#' @param dataset_name Name of the dataset
#' @return List of dataset-specific translations
#' @keywords internal
get_dataset_specific_translations <- function(dataset_name) {
  
  switch(dataset_name,
    "abecip" = list(
      "sbpe" = "sbpe",  # Keep acronym
      "cgi" = "home_equity",
      "rural" = "rural",
      "urbano" = "urban",
      "contratos" = "contracts",
      "valor_medio" = "average_value",
      "prazo_medio" = "average_term"
    ),
    
    "abrainc_indicators" = list(
      "vgv" = "total_sales_value",  # Valor Geral de Vendas
      "vso" = "sales_velocity",     # Velocidade de Vendas
      "estoque" = "inventory",
      "oferta" = "supply",
      "demanda" = "demand",
      "mcmv" = "social_housing",    # Minha Casa Minha Vida
      "cva" = "social_housing",     # Casa Verde Amarela
      "radar" = "business_index"
    ),
    
    "bcb_realestate" = list(
      "contratacao" = "contracting",
      "saldo" = "balance",
      "recursos" = "resources",
      "fonte" = "source",
      "modalidade" = "modality"
    ),
    
    "secovi" = list(
      "vsm" = "price_per_sqm",      # Valor por Metro Quadrado
      "mediana" = "median",
      "amostra" = "sample_size",
      "condominio" = "condo_fee"
    ),
    
    "bis_rppi" = list(
      "rppi" = "property_price_index",
      "residential" = "residential",
      "commercial" = "commercial"
    ),
    
    "cbic" = list(
      "incc" = "construction_cost_index",
      "materiais" = "materials",
      "mao_obra" = "labor",
      "pim" = "industrial_production"
    ),
    
    # Default empty list
    list()
  )
}

#' Clean Column Name
#'
#' Clean and standardize column names that don't have direct translations
#'
#' @param name Original column name
#' @return Cleaned column name
#' @keywords internal
clean_column_name <- function(name) {
  
  # Convert to lowercase
  clean <- tolower(name)
  
  # Remove accents
  clean <- iconv(clean, from = "UTF-8", to = "ASCII//TRANSLIT")
  
  # Replace common patterns
  clean <- gsub("\\u00E7", "c", clean)  # ç
  clean <- gsub("\\u00E3", "a", clean)  # ã
  clean <- gsub("\\u00F5", "o", clean)  # õ
  
  # Replace spaces and special characters with underscores
  clean <- gsub("[^a-z0-9_]", "_", clean)
  
  # Remove duplicate underscores
  clean <- gsub("_+", "_", clean)
  
  # Remove leading/trailing underscores
  clean <- gsub("^_|_$", "", clean)
  
  # Ensure name is not empty
  if (clean == "" || is.na(clean)) {
    clean <- "variable"
  }
  
  return(clean)
}

#' Translate Column Values
#'
#' Translate values within specific columns (e.g., state names, categories)
#'
#' @param df Data frame with potentially translatable values
#' @param dataset_name Dataset name for context
#' @return Data frame with translated values
#' @keywords internal
translate_column_values <- function(df, dataset_name) {
  
  # State name translations (if applicable)
  if ("state" %in% names(df) || "estado" %in% names(df)) {
    state_col <- if ("state" %in% names(df)) "state" else "estado"
    df[[state_col]] <- translate_state_names(df[[state_col]])
  }
  
  # Region name translations
  if ("region" %in% names(df) || "regiao" %in% names(df)) {
    region_col <- if ("region" %in% names(df)) "region" else "regiao" 
    df[[region_col]] <- translate_region_names(df[[region_col]])
  }
  
  # Property type translations
  if ("property_type" %in% names(df) || "tipologia" %in% names(df)) {
    type_col <- if ("property_type" %in% names(df)) "property_type" else "tipologia"
    df[[type_col]] <- translate_property_types(df[[type_col]])
  }
  
  return(df)
}

#' Translate State Names
#'
#' @param state_names Vector of state names in Portuguese
#' @return Vector of state names in English
#' @keywords internal
translate_state_names <- function(state_names) {
  
  # Only translate if they appear to be in Portuguese
  # Keep abbreviations (AC, AL, etc.) as-is
  state_translations <- list(
    "Acre" = "Acre",
    "Alagoas" = "Alagoas", 
    "Amap\\u00E1" = "Amapa",
    "Amazonas" = "Amazonas",
    "Bahia" = "Bahia",
    "Cear\u00E1" = "Ceara",
    "Distrito Federal" = "Federal District",
    "Esp\u00EDrito Santo" = "Espirito Santo",
    "Goi\u00E1s" = "Goias", 
    "Maranh\u00E3o" = "Maranhao",
    "Mato Grosso" = "Mato Grosso",
    "Mato Grosso do Sul" = "Mato Grosso do Sul",
    "Minas Gerais" = "Minas Gerais",
    "Par\u00E1" = "Para",
    "Para\u00EDba" = "Paraiba",
    "Paran\u00E1" = "Parana",
    "Pernambuco" = "Pernambuco",
    "Piau\u00ED" = "Piaui",
    "Rio de Janeiro" = "Rio de Janeiro",
    "Rio Grande do Norte" = "Rio Grande do Norte", 
    "Rio Grande do Sul" = "Rio Grande do Sul",
    "Rond\u00F4nia" = "Rondonia",
    "Roraima" = "Roraima",
    "Santa Catarina" = "Santa Catarina",
    "S\u00E3o Paulo" = "Sao Paulo",
    "Sergipe" = "Sergipe",
    "Tocantins" = "Tocantins"
  )
  
  # Apply translations where available
  translated <- purrr::map_chr(state_names, function(name) {
    state_translations[[name]] %||% name
  })
  
  return(translated)
}

#' Translate Region Names
#'
#' @param region_names Vector of region names
#' @return Vector of translated region names
#' @keywords internal
translate_region_names <- function(region_names) {
  
  region_translations <- list(
    "Norte" = "North",
    "Nordeste" = "Northeast", 
    "Centro-Oeste" = "Center-West",
    "Sudeste" = "Southeast",
    "Sul" = "South",
    "Brasil" = "Brazil"
  )
  
  translated <- purrr::map_chr(region_names, function(name) {
    region_translations[[name]] %||% name
  })
  
  return(translated)
}

#' Translate Property Types
#'
#' @param property_types Vector of property type names
#' @return Vector of translated property types
#' @keywords internal
translate_property_types <- function(property_types) {
  
  type_translations <- list(
    "Apartamento" = "Apartment",
    "Casa" = "House",
    "Terreno" = "Land",
    "Comercial" = "Commercial",
    "Industrial" = "Industrial", 
    "Rural" = "Rural",
    "Cobertura" = "Penthouse",
    "Studio" = "Studio",
    "Kitchenette" = "Studio",
    "Loft" = "Loft"
  )
  
  translated <- purrr::map_chr(property_types, function(type) {
    type_translations[[type]] %||% type
  })
  
  return(translated)
}