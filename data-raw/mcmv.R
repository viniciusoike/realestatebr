library(rvest)
library(dplyr)
library(stringr)

url <- "https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/bases-de-dados-do-programa-minha-casa-minha-vida"

page <- read_html(url)

html_table(page)[[1]]

title <- page |>
  html_elements(xpath = '//td/p/a') |>
  html_text()

link <- page |>
  html_elements(xpath = '//td/p/a') |>
  html_attr("href")

params <- tibble(
  title = title,
  link = link
)

params <- params |>
  mutate(
    ext = stringr::str_extract(link, "(?<=\\.)[a-z]{3,4}$")
  )

csv_links <- params |>
  filter(ext == "csv") |>
  pull(link)

dat <- readr::read_csv2(csv_links[1])

dat |>
  mutate(across(starts_with("vlr"), as.numeric)) |>
  mutate(across(starts_with("txt"), as.character)) |>
  mutate(
    data_referencia = readr::parse_date(data_referencia, format = "%d/%m/%Y")
  )

readr::read_csv2(csv_links[4])

params |>
  filter(ext == "xls") |>
  pull(link)

params |>
  filter(ext == "pdf") |>
  pull(link)

zip_links <- params |>
  filter(ext == "zip") |>
  pull(link)

dirdata <- tempdir()
temp <- tempfile(tmpdir = dirdata, fileext = ".zip")
download.file(zip_links[1], temp)
unzip(temp, exdir = dirdata)
path <- list.files(dirdata, pattern = "\\.csv$", full.names = TRUE)

readr::read_csv2(path)
