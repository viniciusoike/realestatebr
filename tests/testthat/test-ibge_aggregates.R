make_ibge_aggregate_fixture <- function() {
  list(list(
    id = "28",
    variavel = "Produção física industrial",
    unidade = "Número-índice",
    resultados = list(list(
      classificacoes = list(list(
        id = "24",
        nome = "Tipo de índice",
        categoria = list("103340" = "Índice de base fixa")
      )),
      series = list(list(
        localidade = list(
          id = "1",
          nivel = list(id = "N1", nome = "Brasil"),
          nome = "Brasil"
        ),
        serie = list(
          "202601" = "100.5",
          "202602" = "-",
          "202603" = "..."
        )
      ))
    ))
  ))
}

test_that("aggregate responses become long tibbles", {
  result <- parse_ibge_aggregate_chunk(make_ibge_aggregate_fixture(), 2294)

  expect_s3_class(result, "tbl_df")
  expect_equal(result$period, c("202601", "202602", "202603"))
  expect_equal(result$value, c(100.5, 0, NA))
  expect_equal(result$classification_24_code, rep("103340", 3))
  expect_equal(result$geography_level, rep("N1", 3))
})

test_that("aggregate URLs encode query selections", {
  result <- build_ibge_aggregate_url(
    aggregate = 2294,
    variables = 28,
    periods = c("201201", "201202"),
    localities = "N1[all]",
    classifications = "24[103340]|76[2630]"
  )

  expect_match(result, "/2294/periodos/201201\\|201202/variaveis/28")
  expect_match(result, "localidades=N1%5Ball%5D", fixed = TRUE)
  expect_match(
    result,
    "classificacao=24%5B103340%5D%7C76%5B2630%5D",
    fixed = TRUE
  )
})

test_that("IBGE dissemination symbols retain their meanings", {
  result <- parse_ibge_value(c("1.25", "-", "..", "...", "X", NA))

  expect_equal(result, c(1.25, 0, NA, NA, NA, NA))
})

test_that("metadata units replace empty units from data responses", {
  dat <- tibble::tibble(
    variable_id = c("48", "48", "1196"),
    unit = c("", "Reais", "")
  )
  units <- c("48" = "Reais", "1196" = "%")

  result <- apply_ibge_units(dat, units)

  expect_equal(result$unit, c("Reais", "Reais", "%"))
})

test_that("response units are kept for variables missing from metadata", {
  dat <- tibble::tibble(variable_id = c("1", "2"), unit = c("Reais", ""))

  result <- apply_ibge_units(dat, c("3" = "%"))

  expect_equal(result$unit, c("Reais", NA))
})
