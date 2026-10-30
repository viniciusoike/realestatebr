# Parse `/dca` items into the FINBRA long form

`items` holds one list per item
(`jsonlite::fromJSON(simplifyVector = FALSE)` outlines), with fields
`exercicio`, `cod_ibge`, `uf`, `instituicao`, `coluna`, `cod_conta`,
`valor`. The API column labels follow the 2014+ vocabulary for every
year. The result carries the attribute `reporters`:
`<code_muni> <exercicio>` keys of every item, any account; and the
attribute `context` from the current-revenue and tax-revenue items
(gross column only). The API's `populacao` field is ignored: population
comes from IBGE (see
[`fetch_siconfi_population()`](https://viniciusoike.github.io/realestatebr/reference/fetch_siconfi_population.md)).

## Usage

``` r
parse_siconfi_dca(items, call = caller_env())
```
