library(janitor)
library(readxl)
library(dplyr)
library(readr)
library(stringr)

abecip <- read_excel("data-raw/abecip_cgi.xlsx", col_types = "text")

# Rename Column names
abecip <- abecip |>
  clean_names() |>
  rename(
    year = ano,
    month_label = mes,
    loan = valor_emprestimo,
    new_contracts = no_contratos,
    average_term = prazo_medio,
    default_rate = inadimplencia,
    stock_contracts = quantidade_contratos,
    outstanding_balance = saldo_remanescente
  )

# Fix date columns
abecip <- abecip |>
  mutate(
    date = readr::parse_date(
      paste(year, month_label), format = "%Y %B",locale = locale("pt")
      ),
    year = as.numeric(year)
  ) |>
  select(-month_label)

fix_loan <- function(x, decimal = TRUE) {
  # Extract all digits from string. Split by special character
  y <- str_extract_all(x, "\\d+")
  if (decimal) {
    # Paste all numbers together except last bit which are the decimals
    y <- sapply(y, \(z) paste0(paste(z[1:3], collapse = ""), ".", z[4]))
  } else {
    # Paste all numbers together
    y <- sapply(y, paste, collapse = "")
  }

  # Convert to numeric
  as.numeric(y)
}

fix_contract <- function(x, width = 4) {

  # Convert 1.323 to 1323
  # Note some values are missing a trailing 0

  # Remove dots
  y <- str_remove(x, "\\.")
  # Get only first 4 numbers
  y = str_sub(y, 1, 4)
  # Pad zeros if necesary
  y = ifelse(
    str_detect(y, "(^1)|(^2)|(^3)") & str_length(y) == 3,
    str_pad(y, width = 4, side = "right", pad = "0"),
    y
  )
  # Convert to numeric
  as.numeric(y)

}

fix_outstanding_balance <- function(x) {

  # Extract all digits from string. Split by special character
  y <- str_extract_all(x, "\\d+")
  # Paste all numbers together
  y <- sapply(y, paste, collapse = "")
  # Pad zeros if necessary

  y <- ifelse(
    str_detect(y, "^9"),
    str_sub(y, 1, 10),
    str_sub(y, 1, 11)
    )

  y <- ifelse(
    str_detect(y, "^1") & str_length(y) == 10,
    str_pad(y, width = 11, side = "right", pad = "0"),
    y
    )
  # Convert to numeric
  as.numeric(y)

}

fix_stock_contracts <- function(x) {
  # Remove dot
  y = str_remove(x, "\\.")
  # Numbers are either 9xxxx or 1xxxxx
  # If the string starts with a 1 extract 6 digits and pad 0 if needed
  # If the string starts with a 9 extract 5 digits and pad 0 if needed
  y = case_when(
    str_detect(y, "^1") ~ str_pad(str_sub(y, 1, 6), width = 6, side = "right", pad = "0"),
    str_detect(y, "^9") ~ str_pad(str_sub(y, 1, 5), width = 5, side = "right", pad = "0")
  )
  # Convert to numeric
  as.numeric(y)
}

abecip_cgi <- abecip |>
  mutate(
    loan = fix_loan(loan),
    average_term = as.numeric(str_replace(average_term, " ", ".")),
    default_rate = as.numeric(str_remove(default_rate, "%")),
    new_contracts = fix_contract(new_contracts, width = 4),
    stock_contracts = fix_stock_contracts(stock_contracts),
    outstanding_balance = fix_outstanding_balance(outstanding_balance)
  ) |>
  select(
    year, date, new_contracts, stock_contracts, loan, outstanding_balance, average_term, default_rate
  )
