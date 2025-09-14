# IBGE PAIC Data Extraction and Processing
#
# This script extracts and processes IBGE PAIC (Pesquisa Anual da Indústria da
# Construção) data from Brazil's statistical API. It handles multiple geographic
# levels and standardizes the data for analysis.

# Setup ----------------------------------------------------------------------

library(dplyr, warn.conflicts = FALSE)
library(purrr)
library(stringr)
library(rvest)

import::from(janitor, clean_names)
import::from(tidyr, separate)
import::from(sidrar, get_sidra)

# Extract Metadata -------------------------------------------------------------

# Extract available PAIC table metadata from IBGE SIDRA website
url <- "https://sidra.ibge.gov.br/pesquisa/paic/tabelas"

# Scrape table metadata from IBGE website
params <- read_html(url) |>
  html_table() |>
  pluck(4)

# Clean and filter table parameters
params <- params |>
  janitor::clean_names() |>
  filter(!is.na(numero))

# Process table parameters and geographic availability
params_sidra <- params |>
  select(-x) |>
  rename(code_sidra = numero, desc_sidra = nome) |>
  mutate(
    is_br = 1, # All tables available for Brazil
    # Check if table has regional data (GR = Grande Região)
    is_region = if_else(str_detect(territorio, "GR"), 1L, 0L),
    # Check if table has state data (UF = Unidade Federativa)
    is_state = if_else(str_detect(territorio, "UF"), 1L, 0L)
  ) |>
  # Parse time period from "YYYY a YYYY" format
  separate(periodo, into = c("year_start", "year_end"), sep = " a ") |>
  mutate(periodo = str_c(year_start, "-", year_end))

# Create human-readable descriptions for each table
dim_description <- tibble(
  code_sidra = params_sidra$code_sidra,
  desc = c(
    "Gastos de pessoal", # Personnel costs
    "Dados gerais (5+ ocupados)", # General data (5+ employees)
    "Valor incorporações/obras (30+ ocupados)", # Construction value (30+ employees)
    "Dados gerais por atividade", # General data by activity
    "Emprego e salário", # Employment and wages
    "Estrutura das receitas", # Revenue structure
    "Estrutura dos custos", # Cost structure
    "Valor bruto da produção", # Gross production value
    "Estrutura dos investimentos", # Investment structure
    "Consumo de materiais", # Material consumption
    "Dados por faixa de pessoal", # Data by employment size
    "Pessoal, salários e custos (5+ ocupados)", # Personnel, wages, costs (5+ employees)
    "Dados gerais (série encerrada)" # General data (discontinued series)
  ),
  desc_simplified = c(
    "gastos_pessoal",
    "dados_gerais",
    "valor_incorporacoes",
    "dados_gerais_atividade",
    "emprego_salario",
    "estrutura_receitas",
    "estrutura_custos",
    "valor_bruto_producao",
    "estrutura_investimentos",
    "consumo_materiais",
    "dados_gerais_faixa_pessoal",
    "pessoal_salarios_custos",
    "dados_gerais_antigo"
  )
)

# Join descriptions with table parameters
params_sidra <- left_join(
  params_sidra,
  dim_description,
  by = "code_sidra"
)

# Functions --------------------------------------------------------------------
## Data extraction -----------------------------------------------------------

# Extract PAIC data from SIDRA API for multiple geographic levels
#
# @param code SIDRA table code to extract
# @return List containing data for available geographic levels (brasil, grande_regiao, uf)
extract_sidra <- function(code) {
  # Get table parameters for the specified code
  params <- subset(params_sidra, code_sidra == code)

  # Extract Brazil-level data (always available)
  dat <- sidrar::get_sidra(params$code_sidra, period = params$periodo)

  # Initialize output list with Brazil data
  out <- list("brasil" = dat)

  # Extract regional data if available for this table
  if (params$is_region == 1) {
    dat_region <- sidrar::get_sidra(
      params$code_sidra,
      period = params$periodo,
      geo = "Region"
    )

    out[["grande_regiao"]] <- dat_region
  }

  # Extract state data if available for this table
  if (params$is_state == 1) {
    dat_state <- sidrar::get_sidra(
      params$code_sidra,
      period = params$periodo,
      geo = "State"
    )

    out[["uf"]] <- dat_state
  }

  return(out)
}

## Data cleaning -------------------------------------------------------------

### Config --------------------------------------------------------------------

# Columns to remove from raw SIDRA data (redundant or unnecessary)
drop_cols <- c(
  "unidade_de_medida_codigo", # Unit of measure code
  "brasil_codigo", # Brazil code
  "brasil", # Brazil name
  "ano_codigo", # Year code
  "pessoal_ocupado_grupos_e_classes_de_atividades_codigo", # Employment groups code
  "grupos_de_atividades_codigo", # Activity groups code
  "faixas_de_pessoal_ocupado_codigo" # Employment size code
)

# Column name standardization mapping (new_name = old_name)
rename_cols <- c(
  "code_geo" = "nivel_territorial_codigo",
  "name_geo" = "nivel_territorial",
  "code_region" = "grande_regiao_codigo",
  "name_region" = "grande_regiao",
  "code_state" = "unidade_da_federacao_codigo",
  "name_state" = "unidade_da_federacao",
  "unit" = "unidade_de_medida",
  "value" = "valor",
  "code_variable" = "variavel_codigo",
  "variable" = "variavel",
  # Employment by CNAE
  "po_cnae" = "pessoal_ocupado_grupos_e_classes_de_atividades",
  # Construction products
  "construction_products" = "classes_de_atividades_e_descricao_de_produtos_da_construcao",
  # Employment size ranges
  "num_employed" = "faixas_de_pessoal_ocupado",
  # Construction activity groups
  "construction_groups" = "grupos_de_atividade",
  "construction_groups" = "grupos_de_atividades"
)

# Columns that should be converted to numeric
num_cols <- c(
  "code_geo",
  "code_state",
  "code_region",
  "ano",
  "code_variable"
)

# Validation check: ensure no overlap between drop and rename columns
if (any(drop_cols %in% rename_cols)) {
  cli::cli_alert("Review `rename_cols`!")
} else {
  cli::cli_alert_success("OK")
}

### Cleaning functions ----------------------------------------------------------

# Clean employment data by CNAE (economic activity classification)
#
# @param dat Data frame containing po_cnae column
# @return Data frame with parsed CNAE codes and company size classifications
clean_po_cnae <- function(dat) {
  clean_dat <- dat |>
    mutate(
      # Extract CNAE code (format: XX.XX or XX)
      cnae_code = str_extract(po_cnae, "^\\d+(?:\\.\\d+)?"),
      # Extract main group (digits before decimal)
      cnae_group = str_extract(cnae_code, "\\d+(?=\\.)"),
      # Extract subgroup (digits after decimal)
      cnae_subgroup = str_extract(cnae_code, "(?<=\\.)\\d+"),
      # Extract activity description (after "- ")
      cnae_activity = if_else(
        !is.na(cnae_code),
        str_extract(po_cnae, "(?<=- ).+"),
        NA_character_
      ),
      # Classify company size based on employment ranges
      company_size = case_when(
        str_detect(po_cnae, "Empresas entre 1 e 4 de PO") ~ "1-4",
        str_detect(po_cnae, "Empresas entre 5 e 29") ~ "5-29",
        str_detect(po_cnae, "Empresas com 30 ou mais") ~ "30+",
        TRUE ~ NA_character_
      ),
      # Create simplified company class
      company_class = case_when(
        company_size == "1-4" ~ "small",
        company_size == "5-29" ~ "medium",
        company_size == "30+" ~ "large",
        TRUE ~ NA_character_
      )
    )
  return(clean_dat)
}

# Clean construction products classification data
#
# @param dat Data frame containing construction_products column
# @return Data frame with parsed product codes and activity descriptions
clean_construction_products <- function(dat) {
  clean_dat <- dat |>
    mutate(
      # Extract construction product code
      cons_code = str_extract(construction_products, "^\\d+(?:\\.\\d+)?"),
      # Extract main group
      cons_group = str_extract(cons_code, "\\d+"),
      # Extract subgroup (0 if no decimal part)
      cons_subgroup = case_when(
        is.na(cons_code) ~ NA_character_,
        str_detect(cons_code, "\\.") ~ str_extract(cons_code, "(?<=\\.)\\d+"),
        TRUE ~ "0"
      ),
      # Extract activity description (remove code from original)
      cons_activity = if_else(
        !is.na(cons_code),
        str_remove(construction_products, cons_code),
        NA_character_
      ),
      # Clean up whitespace
      cons_activity = str_squish(cons_activity)
    )
  # Count unique combinations and sort by frequency
  # count(
  #   construction_products,
  #   cons_code,
  #   cons_group,
  #   cons_subgroup,
  #   cons_activity,
  #   sort = TRUE
  # )

  return(clean_dat)
}

# Clean construction groups classification data
#
# @param dat Data frame containing construction_groups column
# @return Data frame with parsed CNAE codes and activity descriptions
clean_construction_groups <- function(dat) {
  clean_dat <- dat |>
    mutate(
      cnae_level = str_count(construction_groups, "\\.") + 1,
      # Extract CNAE code from construction groups
      cnae_code = str_extract(construction_groups, "^\\d+(?:\\.\\d+)?"),
      # Extract main group
      cnae_group = str_extract(cnae_code, "\\d+"),
      # Extract subgroup (0 if no decimal part)
      cnae_subgroup = case_when(
        is.na(cnae_code) ~ NA_character_,
        str_detect(cnae_code, "\\.") ~ str_extract(cnae_code, "(?<=\\.)\\d+"),
        TRUE ~ "0"
      ),
      # Extract activity description
      cnae_activity = if_else(
        !is.na(cnae_code),
        str_remove(construction_groups, cnae_code),
        NA_character_
      ),
      # Clean up whitespace
      cnae_activity = str_squish(cnae_activity)
    )

  return(clean_dat)
}

### Main cleaning function ----------------------------------------------------

# Main function to clean and standardize SIDRA data
#
# @param dat Raw data frame from SIDRA API
# @return Cleaned and standardized data frame
clean_sidra <- function(dat) {
  # Apply basic cleaning: standardize names, convert to tibble, rename columns, drop unnecessary columns
  dat <- dat |>
    janitor::clean_names() |>
    as_tibble() |>
    rename(any_of(rename_cols)) |>
    select(-any_of(drop_cols))

  # Convert specified columns to numeric type
  dat <- dat |>
    mutate(across(any_of(num_cols), as.numeric))

  # Apply specialized cleaning based on table structure

  # Clean construction activity groups if present
  if ("grupos_de_atividades" %in% names(dat)) {
    dat <- clean_construction_groups(dat)
  }

  # Clean employment by CNAE data if present
  if ("po_cnae" %in% names(dat)) {
    dat <- clean_po_cnae(dat)
  }

  # Clean construction products data if present
  if ("construction_products" %in% names(dat)) {
    dat <- clean_construction_products(dat)
  }

  return(dat)
}

## Pipeline -------------------------------------------------------------------

# Complete pipeline to extract, clean, and export PAIC data
#
# @param code SIDRA table code to process
# @param outdir Output directory for CSV files (default: data/ibge/PAIC/clean)
# @param export Logical, whether to export CSV files (default: TRUE)
# @param print Logical, whether to return cleaned tables (default: FALSE)
# @return NULL if export=TRUE and print=FALSE, otherwise list of cleaned tables
process_sidra_table <- function(
  code,
  outdir = here::here("data", "ibge", "PAIC", "clean"),
  export = TRUE,
  print = FALSE
) {
  # Extract data from SIDRA API for all available geographic levels
  tables <- suppressMessages(extract_sidra(code))

  # Clean and standardize all extracted tables
  tables <- purrr::map(tables, clean_sidra)

  # Export cleaned tables to CSV files
  if (export) {
    name_table <- subset(params_sidra, code_sidra == code)$desc_simplified
    # Generate file names: sidra_{code}_{geographic_level}.csv
    export_names <- str_glue("{name_table}_{names(tables)}.csv")
    cli::cli_alert_info(
      "Exporting {.file {export_names}} to {.dir {outdir}} ..."
    )

    # Create output directory if it doesn't exist
    if (!dir.exists(outdir)) {
      dir.create(outdir, recursive = TRUE)
    }

    # Write CSV files
    export_paths <- here::here(outdir, export_names)
    purrr::map2(tables, export_paths, readr::write_csv)
    cli::cli_alert_success("Files exported!")
  }

  # Return tables if requested, otherwise return NULL
  if (print) {
    return(tables)
  } else {
    return(NULL)
  }
}

table_codes <- params_sidra$code_sidra
safe_process <- purrr::safely(process_sidra_table)
tables <- purrr::map(table_codes, safe_process, export = FALSE, print = TRUE)

tables <- map(tables[!sapply(tables, is.null)], \(x) x$result)

lapply(tables, \(x) x[[1]])

process_sidra_table(1740, export = FALSE, print = TRUE)

params_sidra
