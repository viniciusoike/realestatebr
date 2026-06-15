# Brazilian Central Bank Series Metadata

A table with metadata for BCB economic series. Use with
`get_dataset("bcb_series")`. The `hierarchy` column controls which
series are returned by default: pass `table = "core"` for the most
relevant real estate series, or a broader level for more macroeconomic
context (see
[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)).

## Usage

``` r
bcb_metadata
```

## Format

### `bcb_metadata`

A data frame with 140 rows and 11 columns:

- code_bcb:

  Numeric code identifying the series.

- bcb_category:

  Category of the series.

- name_simplified:

  Simplified name of the series.

- name_pt:

  Full name of the series in Portuguese.

- name:

  Full name of the series in English.

- unit:

  Unit of the series.

- frequency:

  Frequency of the series.

- first_value:

  Date of the first available observation.

- last_value:

  Date of the last available observation.

- source:

  Source of the series.

- hierarchy:

  Integer relevance tier: 1 = core real estate credit series; 2 =
  primary (key macro series such as SELIC, IPCA, INCC); 3 = secondary
  (broader macro context); 4 = tertiary (less relevant or discontinued
  series).

## Source

<https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries>
