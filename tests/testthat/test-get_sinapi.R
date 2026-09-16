make_sinapi_fixture <- function() {
  list(list(list(
    id = "48",
    variavel = "Custo médio m² - moeda corrente",
    unidade = "Reais",
    resultados = list(list(
      classificacoes = list(),
      series = list(
        list(
          localidade = list(
            id = "1",
            nivel = list(id = "N1", nome = "Brasil"),
            nome = "Brasil"
          ),
          serie = list("202601" = "1900.25", "202602" = "...")
        ),
        list(
          localidade = list(
            id = "35",
            nivel = list(id = "N3", nome = "Unidade da Federação"),
            nome = "São Paulo"
          ),
          serie = list("202601" = "2010.50", "202602" = "2020.75")
        )
      )
    ))
  )))
}

test_that("clean_sinapi returns tidy monthly observations", {
  result <- clean_sinapi(make_sinapi_fixture())

  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c(
      "date",
      "geography_type",
      "geography_code",
      "geography_name",
      "variable",
      "variable_label",
      "unit",
      "value"
    )
  )
  expect_equal(nrow(result), 3L)
  expect_equal(
    result$date,
    as.Date(c("2026-01-01", "2026-01-01", "2026-02-01"))
  )
  expect_equal(result$geography_type, c("brazil", "state", "state"))
  expect_equal(result$value, c(1900.25, 2010.5, 2020.75))
})

test_that("build_sinapi_url requests every supported geography", {
  url <- build_sinapi_url(c("202601", "202602"))

  expect_match(url, "/periodos/202601\\|202602/variaveis/all", perl = TRUE)
  expect_match(
    url,
    "localidades=N1%5Ball%5D%7CN2%5Ball%5D%7CN3%5Ball%5D",
    fixed = TRUE
  )
})

test_that("clean_sinapi rejects unknown upstream identifiers", {
  local_edition(3)
  fixture <- make_sinapi_fixture()
  fixture[[1]][[1]]$id <- "99999"

  expect_snapshot(error = TRUE, clean_sinapi(fixture))
})
