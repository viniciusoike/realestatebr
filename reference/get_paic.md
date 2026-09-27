# Get PAIC Construction Industry Data

Downloads annual Pesquisa Anual da Indústria da Construção (PAIC) data
from IBGE for the new series starting in reference year 2024. The result
covers construction enterprises, employment, revenue, costs, and output.
Do not join this series with the 2007-2023 tables or report growth rates
across the 2023-2024 break (see IBGE Nota técnica 01/2026).

## Usage

``` r
get_paic(table = "activity", quiet = FALSE, max_retries = 3L)
```

## Source

IBGE Pesquisa Anual da Indústria da Construção (PAIC), SIDRA tables
10463, 10441, and 10442

## Arguments

- table:

  Character. One of `'activity'` (default), `'size'`, `'state'`, or
  `'all'`.

- quiet:

  Logical. If `TRUE`, suppresses progress messages.

- max_retries:

  Integer. Maximum retry attempts. Defaults to 3.

## Value

Either a named `list` (when table is `'all'`) or a `tibble` (for
specific tables).
