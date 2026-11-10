make_sidra_fixture <- function() {
  columns <- c(
    "NC", "NN", "MC", "MN", "V",
    "D1C", "D1N", "D2C", "D2N", "D3C", "D3N", "D4C", "D4N", "D5C", "D5N"
  )
  rows <- rbind(
    c(
      "Nível Territorial (Código)", "Nível Territorial",
      "Unidade de Medida (Código)", "Unidade de Medida", "Valor",
      "Brasil (Código)", "Brasil", "Variável (Código)", "Variável",
      "Mês (Código)", "Mês", "Tipo de índice (Código)", "Tipo de índice",
      "Insumos (Código)", "Insumos"
    ),
    c(
      "1", "Brasil", "30", "Número-índice", "100.5",
      "1", "Brasil", "28", "Produção física", "202601", "janeiro 2026",
      "103340", "Índice de base fixa", "2630", "Construção"
    ),
    c(
      "1", "Brasil", "30", "Número-índice", "-",
      "1", "Brasil", "28", "Produção física", "202602", "fevereiro 2026",
      "103340", "Índice de base fixa", "2630", "Construção"
    ),
    c(
      "1", "Brasil", "30", "Número-índice", "...",
      "1", "Brasil", "28", "Produção física", "202603", "março 2026",
      "103340", "Índice de base fixa", "2630", "Construção"
    )
  )
  colnames(rows) <- columns

  return(as.data.frame(rows))
}

test_that("SIDRA responses become long tibbles", {
  result <- parse_sidra_response(
    make_sidra_fixture(),
    aggregate = 2294,
    classifications = "24[103340]|76[2630]"
  )

  expect_s3_class(result, "tbl_df")
  expect_equal(result$aggregate_id, rep("2294", 3))
  expect_equal(result$variable_id, rep("28", 3))
  expect_equal(result$unit, rep("Número-índice", 3))
  expect_equal(result$period, c("202601", "202602", "202603"))
  expect_equal(result$value, c(100.5, 0, NA))
  expect_equal(result$value_raw, c("100.5", "-", "..."))
  expect_equal(result$geography_level, rep("N1", 3))
  expect_equal(result$geography_code, rep("1", 3))
  expect_equal(result$classification_24_code, rep("103340", 3))
  expect_equal(result$classification_76_name, rep("Construção", 3))
})

test_that("a SIDRA response with only the header row is empty", {
  result <- parse_sidra_response(make_sidra_fixture()[1, ], 2294, NULL)

  expect_equal(nrow(result), 0)
})

test_that("a SIDRA layout that differs from the request is rejected", {
  # Two classification columns came back but none was requested.
  expect_error(
    parse_sidra_response(make_sidra_fixture(), 2294, NULL),
    "layout"
  )

  swapped <- make_sidra_fixture()
  swapped[1, "D2N"] <- "Mês"
  expect_error(
    parse_sidra_response(swapped, 2294, "24[103340]|76[2630]"),
    "layout"
  )
})

test_that("SIDRA URLs carry each selection as a path segment", {
  result <- build_ibge_aggregate_url(
    aggregate = 2294,
    variables = c(28, 29),
    periods = c("201201", "201202"),
    localities = "N1[all]|N3[11,12]",
    classifications = "24[103340]|76[2630]"
  )

  expect_equal(
    result,
    paste0(
      "https://apisidra.ibge.gov.br/values/t/2294/n1/all/n3/11,12",
      "/v/28,29/p/201201,201202/c24/103340/c76/2630/f/a/h/y/d/m"
    )
  )
})

test_that("SIDRA URLs work without classifications", {
  result <- build_ibge_aggregate_url(
    aggregate = 2296,
    variables = "all",
    periods = "202601",
    localities = "N1[all]"
  )

  expect_match(result, "/t/2296/n1/all/v/all/p/202601/f/a/h/y/d/m", fixed = TRUE)
})

test_that("empty SIDRA units take the unit of the same variable", {
  dat <- tibble::tibble(
    variable_id = c("48", "48", "1196", "9"),
    unit = c("", "Reais", "%", "")
  )

  result <- fill_sidra_units(dat)

  expect_equal(result$unit, c("Reais", "Reais", "%", NA))
})

test_that("IBGE dissemination symbols retain their meanings", {
  result <- parse_ibge_value(c("1.25", "-", "..", "...", "X", NA))

  expect_equal(result, c(1.25, 0, NA, NA, NA, NA))
})
