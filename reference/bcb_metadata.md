# Brazilian Central Bank Series Metadata

A table with metadata for BCB economic series. Use with
`get_dataset("bcb_series")`.

## Usage

``` r
bcb_metadata
```

## Format

### `bcb_metadata`

A data frame with 140 rows and 10 columns:

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

## Source

<https://www3.bcb.gov.br/sgspub/localizarseries/localizarSeries.do?method=prepararTelaLocalizarSeries>
