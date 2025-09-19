# ==============================================================================
# IMPORT FUNCTIONS (Web scraping and data import)
# ==============================================================================

#' Import CBIC materials metadata from main page
#'
#' Scrapes the main CBIC materials page to extract information about
#' all available construction materials data.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{title}{Character. Material name}
#'     \item{description}{Character. Material description}
#'     \item{link}{Character. URL to material-specific page}
#'   }
#'
#' @examples
#' \dontrun{
#' materials <- import_cbic_materials()
#' }
#' @keywords internal

import_cbic_materials <- function() {
  cli::cli_inform("Fetching CBIC materials metadata...")

  session <- rvest::session("http://www.cbicdados.com.br")
  url <- "http://www.cbicdados.com.br/menu/materiais-de-construcao/"

  page <- session |>
    rvest::session_jump_to(url) |>
    rvest::read_html()

  materials <- rvest::html_elements(page, "a.artigo")

  materials_title <- rvest::html_text2(rvest::html_node(materials, "h3"))
  materials_description <- rvest::html_text2(rvest::html_node(materials, "p"))
  material_links <- rvest::html_attr(materials, "href")

  result <- dplyr::tibble(
    title = materials_title,
    description = materials_description,
    link = material_links
  )

  cli::cli_inform("Found {nrow(result)} materials")
  return(result)
}

#' Import Excel file links for a specific CBIC material
#'
#' @param material_url Character vector of length 1. URL of the material page
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{title}{Character. File title/description}
#'     \item{link}{Character. Direct URL to Excel file}
#'   }
#'
#' @examples
#' \dontrun{
#' cement_url <- "http://www.cbicdados.com.br/menu/materiais-de-construcao/cimento"
#' files <- import_cbic_material_links(cement_url)
#' }
#' @keywords internal

import_cbic_material_links <- function(material_url) {
  cli::cli_inform("Fetching file links from: {material_url}")

  session <- rvest::session("http://www.cbicdados.com.br")

  page <- session |>
    rvest::session_jump_to(material_url) |>
    rvest::read_html()

  table_elements <- rvest::html_elements(page, "div.button-arquivo > a")

  table_titles <- rvest::html_attr(table_elements, "data-content")
  table_links <- rvest::html_attr(table_elements, "href")

  result <- dplyr::tibble(
    title = table_titles,
    link = table_links
  )

  missing_links <- is.na(result$link) | result$link == ""
  if (any(missing_links)) {
    cli::cli_warn("Some links are missing for material: {material_url}")
  }

  cli::cli_inform("Found {nrow(result)} files")
  return(result)
}

#' Import Excel file from CBIC with error handling
#'
#' @param url Character vector of length 1. URL of the Excel file to download
#' @param dest_dir Character vector of length 1. Destination directory
#' @param delay Numeric vector of length 1. Delay between requests in seconds
#'
#' @return Character vector of length 1. Path to downloaded file or NULL if failed
#'
#' @examples
#' \dontrun{
#' url <- "http://www.cbicdados.com.br/media/anexos/example.xlsx"
#' file_path <- import_cbic_file(url)
#' }
#' @keywords internal

import_cbic_file <- function(url, dest_dir = tempdir(), delay = 1) {
  Sys.sleep(delay)

  file_name <- basename(url)
  path_file <- file.path(dest_dir, file_name)

  response <- httr::GET(
    url,
    httr::user_agent("R Web Scraper - Academic Research"),
    httr::write_disk(path_file, overwrite = TRUE)
  )

  if (httr::http_error(response)) {
    cli::cli_warn("Failed to download: {url}")
    return(NULL)
  }

  return(path_file)
}

#' Import all Excel files for a specific CBIC material
#'
#' @param file_params A tibble. Output from import_cbic_material_links()
#' @param dest_dir Character vector of length 1. Destination directory
#'
#' @return A tibble with download results including success status and file paths
#'
#' @examples
#' \dontrun{
#' files <- import_cbic_material_links(cement_url)
#' results <- import_cbic_files(files)
#' }
#' @keywords internal
import_cbic_files <- function(file_params, dest_dir = tempdir()) {
  cli::cli_inform("Downloading {nrow(file_params)} files...")

  results <- file_params |>
    dplyr::mutate(
      file_path = purrr::map_chr(
        link,
        ~ import_cbic_file(.x, dest_dir) %||% NA_character_
      ),
      download_success = !is.na(file_path)
    )

  n_success <- sum(results$download_success)
  n_total <- nrow(results)

  cli::cli_inform("Downloaded {n_success} of {n_total} files successfully")

  return(results)
}

# ==============================================================================
# CLEAN FUNCTIONS (Data cleaning and transformation)
# ==============================================================================

#' Clean CBIC cement monthly consumption data (tabela_07.A.03)
#'
#' **WARNING: This function only works for monthly consumption tables (tabela_07.A.03).**
#' CBIC data is very messy and inconsistent. Each material type likely needs
#' its own cleaning function. Always inspect raw data first before applying cleaning.
#'
#' Processes raw cement consumption data from CBIC Excel files by removing
#' total rows/columns, pivoting to long format, and adding state codes.
#'
#' @param dat A data.frame. Raw data from Excel sheet with 'localidade' column
#' @param year Numeric vector of length 1. Year of the data
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{date}{Date. Monthly date (first day of month)}
#'     \item{year}{Numeric. Year}
#'     \item{code_state}{Character. IBGE state code}
#'     \item{name_state}{Character. State name}
#'     \item{value}{Numeric. Cement consumption value}
#'   }
#'
#' @examples
#' \dontrun{
#' # Only works for monthly consumption tables!
#' cleaned_data <- clean_cbic_cement_monthly(raw_data, 2023)
#' }
#' @keywords internal
clean_cbic_cement_monthly <- function(dat, year) {
  # Check if this looks like cement data
  if (!"localidade" %in% names(dat)) {
    cli::cli_abort(
      "Expected 'localidade' column not found. This may not be a cement table."
    )
  }

  if (ncol(dat) < 5) {
    cli::cli_warn(
      "Very few columns detected. Data structure may be unexpected."
    )
  }

  drop_cols <- c("TOTAL", "Total", "total", "TOTAL GERAL")
  pat_drop_rows <- "^TOTAL|^REGIÃO|^BRASIL|(CENTRO-OESTE)|(CENTRO OESTE)|^Fonte:|^FONTE:"

  dat_clean <- dat |>
    dplyr::select(-dplyr::any_of(drop_cols)) |>
    dplyr::filter(!stringr::str_detect(localidade, pat_drop_rows))

  # Defensive check
  if (nrow(dat_clean) == 0) {
    cli::cli_warn(
      "No data rows remaining after filtering. Check if table structure matches expected format."
    )
    return(tibble::tibble())
  }

  id_cols <- "localidade"

  # Convert all month columns to numeric before pivoting
  dat_clean <- dat_clean |>
    dplyr::mutate(
      dplyr::across(-dplyr::all_of(id_cols), ~ as.numeric(as.character(.x)))
    )

  dat_long <- dat_clean |>
    tidyr::pivot_longer(
      cols = -dplyr::all_of(id_cols),
      names_to = "mes",
      values_to = "value"
    )

  # Try to parse dates - this often fails with messy data
  dat_dated <- dat_long |>
    dplyr::mutate(
      year = year,
      mes = stringr::str_to_lower(mes),
      date = readr::parse_date(
        paste(year, mes, "01", sep = "-"),
        format = "%Y-%b-%d",
        locale = readr::locale("pt", date_names = "pt")
      )
    ) |>
    dplyr::select(localidade, date, year, value)

  # Check for parsing failures
  failed_dates <- sum(is.na(dat_dated$date))
  if (failed_dates > 0) {
    cli::cli_warn(
      "{failed_dates} date parsing failures. Month names may be inconsistent."
    )
  }

  dim_state <- geobr::read_state(year = 2010) |>
    sf::st_drop_geometry() |>
    dplyr::select(code_state, name_state) |>
    dplyr::mutate(
      name_state = stringr::str_replace(
        name_state,
        "Espirito Santo",
        "Espírito Santo"
      )
    )

  result <- dat_dated |>
    dplyr::mutate(localidade = stringr::str_to_title(localidade)) |>
    dplyr::left_join(dim_state, by = c("localidade" = "name_state")) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::select(date, year, code_state, name_state = localidade, value)

  # Final check
  unmatched_states <- sum(is.na(result$code_state))
  if (unmatched_states > 0) {
    cli::cli_warn(
      "{unmatched_states} state name matching failures. State names may be inconsistent."
    )
  }

  return(result)
}

#' Clean CBIC cement annual consumption data (tabela_07.A.01)
#'
#' @param file_path Character. Path to Excel file
#' @param sheet Character or numeric. Sheet to read
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{year}{Numeric. Year}
#'     \item{region}{Character. Region name}
#'     \item{value}{Numeric. Annual consumption value}
#'     \item{variable}{Character. Type of metric (consumption or growth)}
#'   }
#' @keywords internal
clean_cbic_cement_annual <- function(file_path, sheet = 1) {
  # This file has a complex structure with multiple column groups
  # Each group has: Year, Value, Growth %, blank column
  dat <- readxl::read_excel(file_path, sheet = sheet, skip = 4)

  if (ncol(dat) < 8) {
    cli::cli_warn("Unexpected structure for annual cement consumption file")
    return(tibble::tibble())
  }

  # Process in chunks of 4 columns (year, value, growth, blank)
  regions <- c("Brasil", "Centro-Oeste", "Nordeste", "Norte", "Sudeste", "Sul")
  all_data <- list()

  for (i in seq(1, ncol(dat), by = 4)) {
    if (i + 2 > ncol(dat)) {
      break
    }

    region_idx <- ceiling(i / 4)
    if (region_idx > length(regions)) {
      break
    }

    chunk <- dat[, i:min(i + 2, ncol(dat))]
    names(chunk) <- c("year", "consumption", "growth_pct")

    chunk_clean <- chunk |>
      dplyr::filter(!is.na(year)) |>
      dplyr::mutate(
        year = as.numeric(year),
        consumption = as.numeric(consumption),
        growth_pct = as.numeric(growth_pct),
        region = regions[region_idx]
      ) |>
      tidyr::pivot_longer(
        cols = c(consumption, growth_pct),
        names_to = "variable",
        values_to = "value"
      ) |>
      dplyr::select(year, region, variable, value)

    all_data[[region_idx]] <- chunk_clean
  }

  result <- dplyr::bind_rows(all_data)
  return(result)
}

#' Clean CBIC cement production/consumption/export data (tabela_07.A.02)
#'
#' **WARNING: This function only works for production tables (tabela_07.A.02).**
#' Simple year-based structure with multiple metrics as columns.
#'
#' @param file_path Character. Path to Excel file
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{year}{Numeric. Year}
#'     \item{variable}{Character. Metric name}
#'     \item{value}{Numeric. Value}
#'   }
#' @keywords internal
clean_cbic_cement_production <- function(file_path) {
  dat <- readxl::read_excel(file_path, skip = 4)

  if (ncol(dat) < 5) {
    cli::cli_warn("Unexpected structure for cement production file")
    return(tibble::tibble())
  }

  # Expected columns: Year, Production(1000t), Apparent Consumption, Per Capita, Export, Import
  col_names <- c(
    "year",
    "production_1000t",
    "apparent_consumption",
    "per_capita_kg",
    "export",
    "import"
  )

  if (ncol(dat) >= length(col_names)) {
    names(dat)[1:length(col_names)] <- col_names
  } else {
    names(dat) <- col_names[1:ncol(dat)]
  }

  # Convert all columns to numeric first (handling character data)
  result <- dat |>
    dplyr::select(dplyr::all_of(names(dat)[names(dat) %in% col_names])) |>
    dplyr::filter(!is.na(year)) |>
    dplyr::mutate(
      year = as.numeric(year),
      dplyr::across(dplyr::everything(), ~ as.numeric(as.character(.x)))
    ) |>
    tidyr::pivot_longer(
      cols = -year,
      names_to = "variable",
      values_to = "value"
    )

  return(result)
}

#' Clean CBIC cement monthly production data (tabela_07.A.04)
#'
#' **WARNING: This function only works for monthly production tables (tabela_07.A.04).**
#' Similar to consumption but uses "..." for missing data.
#'
#' @param dat A data.frame. Raw data from Excel sheet
#' @param year Numeric. Year of the data
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{date}{Date. Monthly date}
#'     \item{year}{Numeric. Year}
#'     \item{code_state}{Character. IBGE state code}
#'     \item{name_state}{Character. State name}
#'     \item{value}{Numeric. Production value (NA for missing)}
#'   }
#' @keywords internal
clean_cbic_cement_monthly_production <- function(dat, year) {
  # Similar structure to monthly consumption but with "..." for missing values
  if (ncol(dat) < 5) {
    cli::cli_warn("Very few columns detected for monthly production")
    return(tibble::tibble())
  }

  # First column should be state names
  names(dat)[1] <- "localidade"

  # Remove TOTAL column if present
  if ("TOTAL" %in% names(dat)) {
    dat <- dplyr::select(dat, -TOTAL)
  }

  # Filter out summary rows
  pat_drop_rows <- "^TOTAL|^REGIÃO|^BRASIL|(CENTRO-OESTE)|(CENTRO OESTE)|^Fonte:|^FONTE:"
  dat_clean <- dat |>
    dplyr::filter(!stringr::str_detect(localidade, pat_drop_rows))

  if (nrow(dat_clean) == 0) {
    cli::cli_warn("No data rows remaining after filtering")
    return(tibble::tibble())
  }

  # Convert "..." to NA and pivot
  dat_long <- dat_clean |>
    dplyr::mutate(dplyr::across(-localidade, ~ dplyr::na_if(.x, "..."))) |>
    dplyr::mutate(dplyr::across(-localidade, as.numeric)) |>
    tidyr::pivot_longer(
      cols = -localidade,
      names_to = "mes",
      values_to = "value"
    )

  # Parse dates
  dat_dated <- dat_long |>
    dplyr::mutate(
      year = year,
      mes = stringr::str_to_lower(mes),
      date = readr::parse_date(
        paste(year, mes, "01", sep = "-"),
        format = "%Y-%b-%d",
        locale = readr::locale("pt", date_names = "pt")
      )
    ) |>
    dplyr::select(localidade, date, year, value)

  # Add state codes
  dim_state <- get_cbic_dim_state() |>
    dplyr::select(code_state, name_state)

  result <- dat_dated |>
    dplyr::mutate(localidade = stringr::str_to_title(localidade)) |>
    dplyr::left_join(dim_state, by = c("localidade" = "name_state")) |>
    dplyr::select(date, year, code_state, name_state = localidade, value)

  return(result)
}

#' Clean CBIC cement CUB price data (tabela_07.A.05)
#'
#' **WARNING: This function only works for CUB price tables (tabela_07.A.05).**
#' Year and month in first two columns, states as remaining columns.
#'
#' @param file_path Character. Path to Excel file
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{date}{Date. Monthly date}
#'     \item{year}{Numeric. Year}
#'     \item{state}{Character. State abbreviation}
#'     \item{value}{Numeric. CUB cement price (R$/kg)}
#'   }
#' @keywords internal
clean_cbic_cement_cub <- function(file_path) {
  dat <- readxl::read_excel(file_path, skip = 4)

  if (ncol(dat) < 5) {
    cli::cli_warn("Unexpected structure for CUB cement price file")
    return(tibble::tibble())
  }

  # First two columns are year and month
  names(dat)[1:2] <- c("year", "month")

  # Fill down year values
  dat_filled <- dat |>
    tidyr::fill(year, .direction = "down") |>
    dplyr::filter(!is.na(month))

  # Remove Brasil column if present (it's an average)
  if ("Brasil" %in% names(dat_filled)) {
    dat_filled <- dplyr::select(dat_filled, -Brasil)
  }

  # Convert all state columns to numeric before pivoting
  state_cols <- setdiff(names(dat_filled), c("year", "month"))
  dat_filled <- dat_filled |>
    dplyr::mutate(
      dplyr::across(dplyr::all_of(state_cols), ~ as.numeric(as.character(.x)))
    )

  # Pivot state columns
  result <- dat_filled |>
    tidyr::pivot_longer(
      cols = -c(year, month),
      names_to = "state",
      values_to = "value"
    ) |>
    dplyr::mutate(
      year = as.numeric(year),
      month = stringr::str_to_lower(month),
      date = readr::parse_date(
        paste(year, month, "01", sep = "-"),
        format = "%Y-%b-%d",
        locale = readr::locale("pt", date_names = "pt")
      ),
      value = as.numeric(value)
    ) |>
    dplyr::filter(!is.na(value)) |>
    dplyr::select(date, year, state, value)

  return(result)
}

#' Clean CBIC PIM industrial production data
#'
#' Processes the PIM (Pesquisa Industrial Mensal) industrial production index
#' for construction materials. This data uses a unique structure with Excel
#' serial dates for January and month abbreviations for other months.
#'
#' @param file_path Character. Path to the PIM Excel file
#' @param skip Numeric. Number of rows to skip (default = 4)
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{date}{Date. Monthly date}
#'     \item{year}{Numeric. Year}
#'     \item{month}{Character. Month name}
#'     \item{value}{Numeric. Production index (base: 2022 = 100)}
#'   }
#'
#' @examples
#' \dontrun{
#' pim_data <- clean_cbic_pim("path/to/pim_file.xlsx")
#' }
#' @keywords internal
clean_cbic_pim <- function(file_path, skip = 4) {
  dat <- readxl::read_excel(file_path, skip = skip)

  if (ncol(dat) < 2) {
    cli::cli_warn("Unexpected structure for PIM file")
    return(tibble::tibble())
  }

  # Rename columns
  names(dat) <- c("date_raw", "value")

  # Identify rows with Excel serial dates (years)
  excel_date_rows <- grepl("^[0-9]{5}$", dat$date_raw)

  # Convert Excel serial dates to actual dates
  year_dates <- dat$date_raw[excel_date_rows]
  year_values <- as.Date(as.numeric(year_dates), origin = "1899-12-30")
  years <- lubridate::year(year_values)

  # Create a year column by filling down
  dat$year <- NA
  year_indices <- which(excel_date_rows)

  for (i in seq_along(year_indices)) {
    start_idx <- year_indices[i]
    end_idx <- if (i < length(year_indices)) {
      year_indices[i + 1] - 1
    } else {
      nrow(dat)
    }
    dat$year[start_idx:end_idx] <- years[i]
  }

  # Create month column
  dat$month <- dat$date_raw
  dat$month[excel_date_rows] <- "jan"

  # Filter out non-data rows (e.g., source notes at the end)
  dat_clean <- dat |>
    dplyr::filter(
      !is.na(year),
      !is.na(value),
      month %in%
        c(
          "jan",
          "fev",
          "mar",
          "abr",
          "mai",
          "jun",
          "jul",
          "ago",
          "set",
          "out",
          "nov",
          "dez"
        )
    )

  # Create proper date column
  month_map <- c(
    jan = 1,
    fev = 2,
    mar = 3,
    abr = 4,
    mai = 5,
    jun = 6,
    jul = 7,
    ago = 8,
    set = 9,
    out = 10,
    nov = 11,
    dez = 12
  )

  result <- dat_clean |>
    dplyr::mutate(
      month_num = month_map[month],
      date = lubridate::make_date(year, month_num, 1),
      value = as.numeric(value)
    ) |>
    dplyr::select(date, year, month, value) |>
    dplyr::arrange(date)

  # Check for any parsing issues
  if (any(is.na(result$date))) {
    cli::cli_warn("Some dates could not be parsed correctly")
  }

  return(result)
}

#' Process CBIC PIM Excel sheets
#'
#' Wrapper function to process PIM files. Currently handles only the
#' current methodology file (file 3), as files 1 and 2 are historical
#' data with discontinued methodologies.
#'
#' @param download_results A tibble. Output from import_cbic_files()
#'
#' @return A list with the cleaned PIM data
#'
#' @examples
#' \dontrun{
#' download_results <- import_cbic_files(pim_files)
#' pim_data <- clean_cbic_pim_sheets(download_results)
#' }
#' @keywords internal
clean_cbic_pim_sheets <- function(download_results) {
  successful_files <- dplyr::filter(download_results, download_success)

  if (nrow(successful_files) == 0) {
    cli::cli_warn("No PIM files were successfully downloaded")
    return(list())
  }

  cli::cli_inform("Processing PIM industrial production data...")

  # Find the current methodology file (usually the 3rd one or the one with "Atual" in name)
  current_file_idx <- which(
    stringr::str_detect(successful_files$link, "Atual") |
      stringr::str_detect(successful_files$link, "07\\.C\\.03")
  )

  if (length(current_file_idx) == 0) {
    # If no "Atual" file found, use the last one (most recent)
    current_file_idx <- nrow(successful_files)
  }

  file_path <- successful_files$file_path[current_file_idx]
  cli::cli_inform("Processing file: {basename(file_path)}")

  pim_data <- clean_cbic_pim(file_path)

  cli::cli_inform("Processed {nrow(pim_data)} months of PIM data")

  return(list(production_index = pim_data))
}

#' Process CBIC cement Excel sheets specifically
#'
#' Routes to the appropriate cleaning function based on file type.
#'
#' @param download_results A tibble. Output from import_cbic_files()
#' @param skip_rows Numeric vector of length 1. Number of rows to skip when reading Excel
#'
#' @return A list of cleaned cement data frames, named by file type
#'
#' @examples
#' \dontrun{
#' download_results <- import_cbic_files(cement_files)
#' processed_data <- clean_cbic_cement_sheets(download_results)
#' }
#' @keywords internal
clean_cbic_cement_sheets <- function(download_results, skip_rows = 4) {
  read_excel_safe <- purrr::possibly(readxl::read_excel, otherwise = NULL)

  all_data <- list()
  successful_files <- dplyr::filter(download_results, download_success)

  cli::cli_inform("Processing {nrow(successful_files)} cement files...")

  for (i in seq_len(nrow(successful_files))) {
    file_path <- successful_files$file_path[i]
    file_title <- successful_files$title[i]

    cli::cli_inform("Processing file {i}: {file_title}")

    # Detect file type based on content or title patterns
    if (stringr::str_detect(file_title, "consumo anual|07\\.A\\.01")) {
      # File 1: Annual consumption by region
      cli::cli_inform("  Detected as annual consumption file")
      cleaned_data <- clean_cbic_cement_annual(file_path)
      all_data[["annual_consumption"]] <- cleaned_data
    } else if (
      stringr::str_detect(
        file_title,
        "produção.*consumo.*exportação|07\\.A\\.02"
      )
    ) {
      # File 2: Production, consumption, exports
      cli::cli_inform("  Detected as production/export file")
      cleaned_data <- clean_cbic_cement_production(file_path)
      all_data[["production_exports"]] <- cleaned_data
    } else if (stringr::str_detect(file_title, "consumo mensal|07\\.A\\.03")) {
      # File 3: Monthly consumption by state (multiple year sheets)
      cli::cli_inform("  Detected as monthly consumption file")
      sheets <- readxl::excel_sheets(file_path)
      year_sheets <- sheets[!is.na(as.numeric(sheets))]

      monthly_data <- list()
      for (sheet in year_sheets) {
        cli::cli_inform("    Processing sheet: {sheet}")
        dat <- read_excel_safe(file_path, skip = skip_rows, sheet = sheet)

        if (is.null(dat) || nrow(dat) == 0) {
          cli::cli_warn("Failed to read sheet {sheet}")
          next
        }

        names(dat)[1] <- "localidade"
        cleaned_sheet <- clean_cbic_cement_monthly(dat, as.numeric(sheet))
        monthly_data[[sheet]] <- cleaned_sheet
      }
      all_data[["monthly_consumption"]] <- dplyr::bind_rows(monthly_data)
    } else if (stringr::str_detect(file_title, "produção mensal|07\\.A\\.04")) {
      # File 4: Monthly production by state (multiple year sheets)
      cli::cli_inform("  Detected as monthly production file")
      sheets <- readxl::excel_sheets(file_path)
      year_sheets <- sheets[!is.na(as.numeric(sheets))]

      production_data <- list()
      for (sheet in year_sheets) {
        cli::cli_inform("    Processing sheet: {sheet}")
        dat <- read_excel_safe(file_path, skip = skip_rows, sheet = sheet)

        if (is.null(dat) || nrow(dat) == 0) {
          cli::cli_warn("Failed to read sheet {sheet}")
          next
        }

        cleaned_sheet <- clean_cbic_cement_monthly_production(
          dat,
          as.numeric(sheet)
        )
        production_data[[sheet]] <- cleaned_sheet
      }
      all_data[["monthly_production"]] <- dplyr::bind_rows(production_data)
    } else if (stringr::str_detect(file_title, "CUB|07\\.A\\.05")) {
      # File 5: CUB cement prices
      cli::cli_inform("  Detected as CUB price file")
      cleaned_data <- clean_cbic_cement_cub(file_path)
      all_data[["cub_prices"]] <- cleaned_data
    } else {
      cli::cli_warn("  Unknown file type, skipping: {file_title}")
    }
  }

  cli::cli_inform("Processed cement data successfully")
  return(all_data)
}

#' Explore CBIC Excel file structure (for messy data investigation)
#'
#' **Use this function first** when working with new CBIC materials.
#' CBIC data is very inconsistent - always explore structure before creating cleaning functions.
#'
#' @param file_path Character. Path to downloaded Excel file
#' @param sheet Character. Sheet name or number to explore (default: first sheet)
#'
#' @return Prints structure information and returns raw data for inspection
#'
#' @examples
#' \dontrun{
#' files <- get_cbic_files("aço")
#' explore_cbic_structure(files$file_path[1])
#' }
#'
#' @keywords internal
explore_cbic_structure <- function(file_path, sheet = 1) {
  cli::cli_h2("Exploring CBIC file structure: {basename(file_path)}")

  # Get all sheets
  sheets <- readxl::excel_sheets(file_path)
  cli::cli_inform("Available sheets: {paste(sheets, collapse = ', ')}")

  # Read the specified sheet
  cli::cli_inform("Reading sheet: {sheet}")

  dat_raw <- readxl::read_excel(file_path, sheet = sheet)
  cli::cli_inform(
    "Raw dimensions: {nrow(dat_raw)} rows x {ncol(dat_raw)} columns"
  )
  cli::cli_inform("Column names: {paste(names(dat_raw), collapse = ', ')}")

  # Try with skip = 4 (common for CBIC)
  dat_skip <- readxl::read_excel(file_path, sheet = sheet, skip = 4)
  cli::cli_inform(
    "With skip=4: {nrow(dat_skip)} rows x {ncol(dat_skip)} columns"
  )
  cli::cli_inform(
    "Columns after skip: {paste(names(dat_skip), collapse = ', ')}"
  )

  # Look for patterns
  cli::cli_h3("First few rows (skip=4):")
  print(utils::head(dat_skip))

  cli::cli_h3("Data types:")
  print(sapply(dat_skip, class))

  cli::cli_warn(
    "IMPORTANT: Inspect this output carefully before creating cleaning functions!"
  )

  return(invisible(dat_skip))
}

# ==============================================================================
# MATERIAL-SPECIFIC CLEANING HELPERS
# ==============================================================================

#' Clean CBIC steel price data (file 1)
#'
#' **WARNING: This function only works for steel price tables.**
#' Steel data has different structure than cement data.
#'
#' @param file_path Character. Path to steel prices Excel file
#' @param skip_rows Numeric. Number of rows to skip when reading Excel
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{date}{Date. Monthly date}
#'     \item{year}{Numeric. Year}
#'     \item{code_state}{Character. IBGE state code}
#'     \item{name_state}{Character. State name}
#'     \item{avg_price}{Numeric. Average steel price}
#'   }
#'
#' @examples
#' \dontrun{
#' steel_files <- get_cbic_files("aço")
#' prices <- clean_cbic_steel_prices(steel_files$file_path[1])
#' }
#' @keywords internal
clean_cbic_steel_prices <- function(file_path, skip_rows = 4) {
  drop_cols <- c("TOTAL", "Total", "total", "TOTAL GERAL", "Brasil", "BRASIL")

  dat <- readxl::read_excel(file_path, skip = skip_rows)

  if (ncol(dat) < 3) {
    cli::cli_warn(
      "Very few columns detected for steel prices. Structure may be unexpected."
    )
    return(tibble::tibble())
  }

  names(dat)[1:2] <- c("year", "month_abb")
  id_cols <- c("date", "year")

  dat_processed <- dat |>
    dplyr::select(-dplyr::any_of(drop_cols)) |>
    tidyr::fill(year) |>
    dplyr::mutate(
      year = as.numeric(year),
      month_abb = stringr::str_to_title(month_abb),
      date = readr::parse_date(
        paste0(year, "-", month_abb),
        format = "%Y-%b",
        locale = readr::locale("pt", date_names = "pt")
      ),
      .before = 1
    ) |>
    dplyr::select(-"month_abb")

  # Get state dimension data
  dim_state <- get_cbic_dim_state() |>
    dplyr::select(abbrev_state, name_state, code_state)

  result <- dat_processed |>
    tidyr::pivot_longer(
      cols = -dplyr::all_of(id_cols),
      names_to = "abbrev_state",
      values_to = "avg_price"
    ) |>
    dplyr::left_join(dim_state, by = "abbrev_state") |>
    dplyr::select(date, year, code_state, name_state, avg_price)

  # Check for unmatched states
  unmatched_states <- sum(is.na(result$code_state))
  if (unmatched_states > 0) {
    cli::cli_warn(
      "{unmatched_states} state abbreviation matching failures in steel prices."
    )
  }

  return(result)
}

#' Clean CBIC steel production data (file 2)
#'
#' **WARNING: This function only works for steel production tables.**
#' This handles complex multi-header Excel structure.
#'
#' @param file_path Character. Path to steel production Excel file
#' @param skip_rows Numeric. Number of rows to skip for headers
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{year}{Numeric. Year}
#'     \item{product}{Character. Steel product type}
#'     \item{variable}{Character. Variable measured}
#'     \item{value}{Numeric. Production value}
#'   }
#'
#' @examples
#' \dontrun{
#' steel_files <- get_cbic_files("aço")
#' production <- clean_cbic_steel_production(steel_files$file_path[2])
#' }
#' @keywords internal
clean_cbic_steel_production <- function(file_path, skip_rows = 3) {
  # Read multi-level headers
  header <- readxl::read_excel(
    file_path,
    skip = skip_rows,
    n_max = 3,
    col_names = FALSE,
    .name_repair = janitor::make_clean_names
  )

  if (ncol(header) < 3) {
    cli::cli_warn("Very few columns detected for steel production headers.")
    return(tibble::tibble())
  }

  # Process headers - fill right to handle merged cells
  header_processed <- header |>
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character)) |>
    purrr::pmap(\(...) {
      zoo::na.locf(c(...)) |>
        as.list() |>
        tibble::as_tibble_row()
    }) |>
    purrr::list_rbind()

  # Create clean column names
  cnames <- purrr::map_chr(
    header_processed,
    ~ paste(stats::na.omit(.x), collapse = "@")
  )
  cnames <- lapply(stringr::str_split(cnames, "@"), clean_cbic_string)
  cnames <- purrr::map_chr(cnames, ~ paste(stats::na.omit(.x), collapse = "/"))
  cnames <- stringr::str_remove(cnames, "_mil_t$")

  # Read actual data
  dat <- readxl::read_excel(
    file_path,
    skip = skip_rows + 3,
    col_names = cnames,
    na = "..."
  )

  if (nrow(dat) == 0) {
    cli::cli_warn("No data rows found in steel production file.")
    return(tibble::tibble())
  }

  result <- dat |>
    dplyr::rename(year = 1) |>
    dplyr::mutate(dplyr::across(dplyr::everything(), as.numeric)) |>
    tidyr::pivot_longer(cols = -"year", names_to = "series_name") |>
    tidyr::separate_wider_delim(
      series_name,
      delim = "/",
      names = c("product", "state", "unit"),
      too_many = "merge",
      too_few = "align_start"
    ) |>
    dplyr::mutate(
      variable = dplyr::if_else(is.na(unit), state, unit),
      product = stringr::str_remove(product, "_total$"),
      product = dplyr::if_else(
        product == "perfis",
        stringr::str_c(product, "_", state),
        product
      )
    ) |>
    dplyr::select(year, product, variable, value)

  return(result)
}

#' Helper function to get state dimension data for CBIC
#'
#' @return A tibble with state codes, names, and abbreviations
get_cbic_dim_state <- function() {
  states <- geobr::read_state(year = 2010, showProgress = FALSE)
  states <- dplyr::as_tibble(sf::st_drop_geometry(states))

  dim_state <- states |>
    dplyr::mutate(
      name_state = stringr::str_replace(
        name_state,
        "Espirito Santo",
        "Espírito Santo"
      )
    )

  return(dim_state)
}

#' Helper function to clean strings for CBIC column names
#'
#' @param x Character vector to clean
#' @return Cleaned character vector
#' @keywords internal
clean_cbic_string <- function(x) {
  y <- stringr::str_remove_all(x, "\\\\d+")
  y <- stringi::stri_trans_general(y, "latin-ascii")
  y <- stringr::str_remove_all(y, "[:punct:]")
  y <- stringr::str_squish(y)
  y <- stringr::str_replace_all(y, " ", "_")
  y <- stringr::str_to_lower(y)
  return(y)
}

#' Process CBIC steel Excel files
#'
#' Handles both steel price and production files with appropriate cleaning.
#'
#' @param download_results A tibble. Output from import_cbic_files()
#'
#' @return A list with 'prices' and 'production' data frames
#'
#' @examples
#' \dontrun{
#' steel_files <- get_cbic_files("aço")
#' steel_data <- clean_cbic_steel_sheets(steel_files)
#' }
#' @keywords internal
clean_cbic_steel_sheets <- function(download_results) {
  successful_files <- dplyr::filter(download_results, download_success)

  cli::cli_inform("Processing {nrow(successful_files)} steel files...")

  if (nrow(successful_files) == 0) {
    cli::cli_warn("No successful steel file downloads to process.")
    return(list())
  }

  all_data <- list()

  for (i in seq_len(nrow(successful_files))) {
    file_path <- successful_files$file_path[i]
    file_title <- successful_files$title[i]

    cli::cli_inform("Processing steel file: {file_title}")

    # Determine file type based on position or title
    if (
      i == 1 ||
        stringr::str_detect(stringr::str_to_lower(file_title), "preço|price")
    ) {
      # Assume first file or files with "preço" are price data
      prices_data <- clean_cbic_steel_prices(file_path)
      all_data[["prices"]] <- prices_data
    } else {
      # Assume other files are production data
      production_data <- clean_cbic_steel_production(file_path)
      all_data[[paste0("production_", i)]] <- production_data
    }
  }

  cli::cli_inform("Processed steel data successfully")
  return(all_data)
}

# ==============================================================================
# GET FUNCTIONS (Main user-facing functions)
# ==============================================================================

#' Get raw CBIC files for a specific material
#'
#' Downloads all Excel files for a construction material from CBIC database.
#' Returns raw download results for custom processing.
#'
#' @param material_name Character vector of length 1. Name of material (e.g., "cimento")
#'
#' @return A tibble with download results including file paths
#'
#' @examples
#' \dontrun{
#' cement_files <- get_cbic_files("cimento")
#' }
#'
#' @keywords internal
get_cbic_files <- function(material_name) {
  cli::cli_h1("Getting CBIC files for {material_name}")

  materials <- import_cbic_materials()

  material_matches <- stringr::str_detect(
    stringr::str_to_lower(materials$title),
    stringr::str_to_lower(material_name)
  )

  if (!any(material_matches)) {
    cli::cli_abort("Material '{material_name}' not found")
  }

  material_url <- materials$link[which(material_matches)[1]]

  file_params <- import_cbic_material_links(material_url)
  download_results <- import_cbic_files(file_params)

  cli::cli_h1("CBIC file download complete")
  return(download_results)
}

#' Get CBIC cement consumption data
#'
#' Complete workflow to get cleaned cement consumption data from CBIC.
#' Includes annual, monthly, production, and CUB price data.
#'
#' @param table Character. Which dataset to return: "annual_consumption",
#'   "production_exports", "monthly_consumption", "monthly_production",
#'   "cub_prices", or "all" (default: "monthly_consumption")
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If TRUE, try to load data from cache first (default: FALSE)
#' @param quiet Logical. If TRUE, suppress progress messages (default: FALSE)
#' @param max_retries Integer. Maximum number of retry attempts for downloads (default: 3L)
#'
#' @return A tibble with cement data, or a list if table = "all"
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' about web scraping, file downloads, and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and robust error
#' handling for malformed Excel files.
#'
#' @examples
#' \dontrun{
#' # Get monthly consumption data (default)
#' monthly_data <- get_cbic_cement()
#'
#' # Get all datasets
#' all_cement <- get_cbic_cement(table = "all")
#'
#' # Get specific dataset with progress reporting
#' prices <- get_cbic_cement(table = "cub_prices", quiet = FALSE)
#' }
#'
#' @keywords internal
get_cbic_cement <- function(table = "monthly_consumption",
                           category = NULL,
                           cached = FALSE,
                           quiet = FALSE,
                           max_retries = 3L) {

  # Input validation and backward compatibility ----
  valid_tables <- c("annual_consumption", "production_exports", "monthly_consumption",
                    "monthly_production", "cub_prices", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn(c(
      "Parameter {.arg category} is deprecated",
      "i" = "Use {.arg table} parameter instead",
      ">" = "This will be removed in a future version"
    ))
    table <- category
  }

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Cached data loading not yet implemented for CBIC datasets")
    }
  }

  # Main data processing ----
  if (!quiet) {
    cli::cli_h1("Getting CBIC cement data")
  }

  attempts <- 0
  cement_data <- NULL

  while (attempts <= max_retries && is.null(cement_data)) {
    attempts <- attempts + 1

    tryCatch({
      materials <- import_cbic_materials()
      cement_url <- materials$link[stringr::str_detect(
        stringr::str_to_lower(materials$title),
        "cimento"
      )][1]

      if (is.na(cement_url)) {
        cli::cli_abort("Cement material not found in CBIC database")
      }

      file_params <- import_cbic_material_links(cement_url)
      download_results <- import_cbic_files(file_params)
      cement_data <- clean_cbic_cement_sheets(download_results)

    }, error = function(e) {
      if (attempts > max_retries) {
        cli::cli_abort(c(
          "Failed to retrieve CBIC cement data after {max_retries} attempts",
          "x" = "Error: {e$message}",
          "i" = "Check your internet connection and try again"
        ))
      }

      if (!quiet) {
        cli::cli_warn("Attempt {attempts} failed, retrying...")
      }

      # Exponential backoff
      Sys.sleep(min(attempts * 0.5, 3))
    })
  }

  # Return requested data ----
  if (table == "all") {
    result <- cement_data
  } else {
    result <- cement_data[[table]]
    if (is.null(result)) {
      cli::cli_abort("Requested table '{table}' not found in cement data")
    }
  }

  # Add metadata attributes ----
  attr(result, "source") <- "web"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    total_records = if(is.list(result)) sum(sapply(result, nrow)) else nrow(result),
    retry_attempts = attempts,
    source = "CBIC"
  )

  if (!quiet) {
    cli::cli_h1("CBIC cement data retrieval complete")
  }

  return(result)
}

#' Get CBIC steel data (prices and production)
#'
#' Complete workflow to get cleaned steel price and production data from CBIC.
#' Returns steel price data by default, or all datasets when requested.
#'
#' @param table Character. Which dataset to return: "prices", "production", or "all" (default: "prices")
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If TRUE, try to load data from cache first (default: FALSE)
#' @param quiet Logical. If TRUE, suppress progress messages (default: FALSE)
#' @param max_retries Integer. Maximum number of retry attempts for downloads (default: 3L)
#'
#' @return A tibble with steel data, or a list if table = "all"
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' about web scraping, file downloads, and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and robust error
#' handling for malformed Excel files.
#'
#' @examples
#' \dontrun{
#' # Get steel prices (default)
#' prices <- get_cbic_steel()
#'
#' # Get all steel datasets
#' all_steel <- get_cbic_steel(table = "all")
#'
#' # Get production data with progress reporting
#' production <- get_cbic_steel(table = "production", quiet = FALSE)
#' }
#'
#' @keywords internal
get_cbic_steel <- function(table = "prices",
                          category = NULL,
                          cached = FALSE,
                          quiet = FALSE,
                          max_retries = 3L) {

  # Input validation and backward compatibility ----
  valid_tables <- c("prices", "production", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn(c(
      "Parameter {.arg category} is deprecated",
      "i" = "Use {.arg table} parameter instead",
      ">" = "This will be removed in a future version"
    ))
    table <- category
  }

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Cached data loading not yet implemented for CBIC datasets")
    }
  }

  # Main data processing ----
  if (!quiet) {
    cli::cli_h1("Getting CBIC steel data")
  }

  attempts <- 0
  steel_data <- NULL

  while (attempts <= max_retries && is.null(steel_data)) {
    attempts <- attempts + 1

    tryCatch({
      materials <- import_cbic_materials()
      steel_url <- materials$link[stringr::str_detect(
        stringr::str_to_lower(materials$title),
        "aço"
      )][1]

      if (is.na(steel_url)) {
        cli::cli_abort("Steel material not found in CBIC database")
      }

      file_params <- import_cbic_material_links(steel_url)
      download_results <- import_cbic_files(file_params)
      steel_data <- clean_cbic_steel_sheets(download_results)

    }, error = function(e) {
      if (attempts > max_retries) {
        cli::cli_abort(c(
          "Failed to retrieve CBIC steel data after {max_retries} attempts",
          "x" = "Error: {e$message}",
          "i" = "Check your internet connection and try again"
        ))
      }

      if (!quiet) {
        cli::cli_warn("Attempt {attempts} failed, retrying...")
      }

      # Exponential backoff
      Sys.sleep(min(attempts * 0.5, 3))
    })
  }

  # Return requested data ----
  if (table == "all") {
    result <- steel_data
  } else if (table == "prices") {
    result <- steel_data[["prices"]]
    if (is.null(result)) {
      cli::cli_abort("Price data not found in steel data")
    }
  } else if (table == "production") {
    # Return first production table found
    production_tables <- steel_data[grepl("production", names(steel_data))]
    if (length(production_tables) == 0) {
      cli::cli_abort("Production data not found in steel data")
    }
    result <- production_tables[[1]]
  }

  # Add metadata attributes ----
  attr(result, "source") <- "web"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    total_records = if(is.list(result)) sum(sapply(result, nrow)) else nrow(result),
    retry_attempts = attempts,
    source = "CBIC"
  )

  if (!quiet) {
    cli::cli_h1("CBIC steel data retrieval complete")
  }

  return(result)
}

#' Get CBIC PIM industrial production data
#'
#' Complete workflow to get cleaned PIM (Pesquisa Industrial Mensal) industrial
#' production index data from CBIC. This data tracks the physical production
#' of typical construction industry inputs in Brazil.
#'
#' @param table Character. Which dataset to return: "production_index" or "all" (default: "production_index")
#' @param category Character. Deprecated parameter name for backward compatibility.
#'   Use `table` instead.
#' @param cached Logical. If TRUE, try to load data from cache first (default: FALSE)
#' @param quiet Logical. If TRUE, suppress progress messages (default: FALSE)
#' @param max_retries Integer. Maximum number of retry attempts for downloads (default: 3L)
#'
#' @return A tibble with PIM production index data, or a list if table = "all"
#'
#' @details
#' The PIM data uses production index with base year 2022 = 100. The data
#' covers monthly observations from 2012 onwards. Note that files 1 and 2
#' available on CBIC website contain historical data with discontinued
#' methodologies and are not processed by this function.
#'
#' @section Progress Reporting:
#' When `quiet = FALSE`, the function provides detailed progress information
#' about web scraping, file downloads, and data processing steps.
#'
#' @section Error Handling:
#' The function includes retry logic for failed downloads and robust error
#' handling for malformed Excel files.
#'
#' @examples
#' \dontrun{
#' # Get production index data (default)
#' production <- get_cbic_pim()
#'
#' # Get all PIM datasets
#' all_pim <- get_cbic_pim(table = "all")
#'
#' # Get data with progress reporting
#' production <- get_cbic_pim(quiet = FALSE)
#' }
#'
#' @keywords internal
get_cbic_pim <- function(table = "production_index",
                        category = NULL,
                        cached = FALSE,
                        quiet = FALSE,
                        max_retries = 3L) {

  # Input validation and backward compatibility ----
  valid_tables <- c("production_index", "all")

  # Handle backward compatibility: if category is provided, use it as table
  if (!is.null(category)) {
    cli::cli_warn(c(
      "Parameter {.arg category} is deprecated",
      "i" = "Use {.arg table} parameter instead",
      ">" = "This will be removed in a future version"
    ))
    table <- category
  }

  if (!is.character(table) || length(table) != 1) {
    cli::cli_abort(c(
      "Invalid {.arg table} parameter",
      "x" = "{.arg table} must be a single character string",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  if (!table %in% valid_tables) {
    cli::cli_abort(c(
      "Invalid table: {.val {table}}",
      "i" = "Valid tables: {.val {valid_tables}}"
    ))
  }

  # Handle cached data ----
  if (cached) {
    if (!quiet) {
      cli::cli_inform("Cached data loading not yet implemented for CBIC datasets")
    }
  }

  # Main data processing ----
  if (!quiet) {
    cli::cli_h1("Getting CBIC PIM industrial production data")
  }

  attempts <- 0
  pim_data <- NULL

  while (attempts <= max_retries && is.null(pim_data)) {
    attempts <- attempts + 1

    tryCatch({
      materials <- import_cbic_materials()
      pim_url <- subset(materials, title == "PIM")$link

      if (is.na(pim_url) || length(pim_url) == 0) {
        cli::cli_abort("PIM material not found in CBIC database")
      }

      file_params <- import_cbic_material_links(pim_url)
      download_results <- import_cbic_files(file_params)
      pim_data <- clean_cbic_pim_sheets(download_results)

    }, error = function(e) {
      if (attempts > max_retries) {
        cli::cli_abort(c(
          "Failed to retrieve CBIC PIM data after {max_retries} attempts",
          "x" = "Error: {e$message}",
          "i" = "Check your internet connection and try again"
        ))
      }

      if (!quiet) {
        cli::cli_warn("Attempt {attempts} failed, retrying...")
      }

      # Exponential backoff
      Sys.sleep(min(attempts * 0.5, 3))
    })
  }

  # Return requested data ----
  if (table == "all") {
    result <- pim_data
  } else {
    result <- pim_data[["production_index"]]
    if (is.null(result)) {
      cli::cli_abort("Production index data not found in PIM data")
    }
  }

  # Add metadata attributes ----
  attr(result, "source") <- "web"
  attr(result, "download_time") <- Sys.time()
  attr(result, "download_info") <- list(
    table = table,
    total_records = if(is.list(result)) sum(sapply(result, nrow)) else nrow(result),
    retry_attempts = attempts,
    source = "CBIC"
  )

  if (!quiet) {
    cli::cli_h1("CBIC PIM data retrieval complete")
  }

  return(result)
}

#' Get available CBIC materials
#'
#' Get metadata about all construction materials available in CBIC database.
#'
#' @return A tibble with material titles, descriptions, and links
#'
#' @examples
#' \dontrun{
#' materials <- get_cbic_materials()
#' }
#'
#' @keywords internal
get_cbic_materials <- function() {
  import_cbic_materials()
}
