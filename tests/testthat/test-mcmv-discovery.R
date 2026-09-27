mcmv_discovery <- function() {
  root <- normalizePath(testthat::test_path("..", ".."))
  env <- new.env(parent = globalenv())
  withr::with_dir(root, sys.source("data-raw/mcmv/discover_sources.R", env))
  return(env)
}

landing_html <- function(extra = character()) {
  html <- readLines(test_path("fixtures/mcmv/landing.html"), encoding = "UTF-8")
  closing <- which(html == "  </body>")
  return(c(html[seq_len(closing - 1)], extra, html[closing:length(html)]))
}

test_that("discovery finds one data file per table on the landing page", {
  d <- mcmv_discovery()
  urls <- d$discover_mcmv_sources(landing_html())
  expect_named(urls, c("financing", "financing_summary", "subsidized_projects"))
  expect_match(urls[["financing"]], "/mcmv_financ_analitico_20260724[.]zip$")
  expect_match(
    urls[["financing_summary"]],
    "/mcmv_financ_sintetico_20260724_v2[.]zip$"
  )
  expect_match(
    urls[["subsidized_projects"]],
    "/mcmv_subsidiado_202606302[.]zip$"
  )
})

test_that("discovery ignores repeated links to the same file", {
  d <- mcmv_discovery()
  html <- landing_html()
  repeated <- grep("mcmv_financ_analitico_", html, value = TRUE)
  urls <- d$discover_mcmv_sources(c(html[1:4], repeated, html[-(1:4)]))
  expect_length(urls, 3L)
})

test_that("discovery fails when a table has no link or several links", {
  d <- mcmv_discovery()
  html <- landing_html()
  expect_error(
    d$discover_mcmv_sources(grep(
      "mcmv_subsidiado_",
      html,
      value = TRUE,
      invert = TRUE
    )),
    "subsidized_projects"
  )
  second <- '<a href="https://www.gov.br/arquivos/mcmv_subsidiado_20260930.zip">x</a>'
  expect_error(
    d$discover_mcmv_sources(landing_html(second)),
    "subsidized_projects"
  )
})

test_that("discovery resolves relative links against the page URL", {
  d <- mcmv_discovery()
  html <- landing_html()
  html <- sub(
    "https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/arquivos/",
    "arquivos/",
    html,
    fixed = TRUE
  )
  urls <- d$discover_mcmv_sources(
    html,
    base_url = "https://www.gov.br/cidades/mcmv/"
  )
  expect_identical(
    urls[["financing_summary"]],
    "https://www.gov.br/cidades/mcmv/arquivos/mcmv_financ_sintetico_20260724_v2.zip"
  )
})

test_that("changes are detected against the published manifest", {
  d <- mcmv_discovery()
  urls <- d$discover_mcmv_sources(landing_html())
  manifest <- list(
    source = list(
      files = lapply(
        as.list(urls),
        function(url) list(url = url)
      )
    )
  )
  expect_false(d$mcmv_sources_changed(urls, manifest))
  newer <- "https://www.gov.br/arquivos/mcmv_subsidiado_20260930.zip"
  changed <- urls
  changed[["subsidized_projects"]] <- newer
  expect_true(d$mcmv_sources_changed(changed, manifest))
  expect_true(d$mcmv_sources_changed(urls, NULL))
  manifest$source$files$financing$url <- NULL
  expect_true(d$mcmv_sources_changed(urls, manifest))
})

test_that("snapshot version comes from the reference date inside the file", {
  d <- mcmv_discovery()
  csv <- test_path("fixtures/mcmv/financing_july.csv")
  expect_identical(d$mcmv_reference_version(csv), "2026-07-24")

  skip_if(!nzchar(Sys.which("bsdtar")), "bsdtar is not installed")
  dir <- withr::local_tempdir()
  file.copy(csv, file.path(dir, "analitico.csv"))
  archive <- file.path(dir, "analitico.zip")
  withr::with_dir(
    dir,
    system2("bsdtar", c("-a", "-cf", "analitico.zip", "analitico.csv"))
  )
  expect_identical(d$mcmv_reference_version(archive), "2026-07-24")

  bad <- file.path(dir, "bad.csv")
  writeLines(c('"data_referencia";"cod_ibge"', '"2026-07-24";"110020"'), bad)
  expect_error(d$mcmv_reference_version(bad), "DD/MM/YYYY")
})
