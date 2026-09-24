# Get Dataset

Unified interface for accessing all realestatebr datasets. Resolves data
from the package's GitHub release assets when possible (fast,
pre-processed, updated weekly by CI) and falls back to a fresh download
from the original source. Repeated calls within one R session are served
from an in-memory memo to avoid redundant network traffic.

## Usage

``` r
get_dataset(
  name,
  table = NULL,
  source = "auto",
  date_start = NULL,
  date_end = NULL,
  quiet = FALSE,
  ...
)
```

## Arguments

- name:

  Character. Dataset name (see
  [`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
  for options). Each dataset has its own help topic documenting tables
  and columns:
  [abecip](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
  [abrainc](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
  [bcb_realestate](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
  [bcb_series](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
  [fgv_ibre](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
  [pim_pf_construction](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
  [rppi](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
  [rppi_bis](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
  [secovi](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
  and
  [sinapi](https://viniciusoike.github.io/realestatebr/reference/sinapi.md).

- table:

  Character. Specific table within a multi-table dataset. See
  [`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
  for available tables per dataset.

- source:

  Character. Data source preference:

  "auto"

  :   Use the in-session memo if available, otherwise GitHub releases,
      otherwise fresh download (default).

  "github"

  :   Pre-processed asset from the package's GitHub release.

  "fresh"

  :   Fresh download from the original source.

  Use
  [`clear_session_cache`](https://viniciusoike.github.io/realestatebr/reference/clear_session_cache.md)
  to drop the in-session memo.

- date_start:

  Date. Optional first date to retain for time-series datasets. Retained
  for compatibility; filtering is applied after the dataset is loaded.

- date_end:

  Date. Optional last date to retain for time-series datasets. Retained
  for compatibility; filtering is applied after the dataset is loaded.

- quiet:

  Logical. If `TRUE`, suppresses informational messages. Errors and
  warnings are still shown.

- ...:

  Additional arguments passed to the internal function when a fresh
  download is required. Retained for compatibility with the 1.0.1
  interface.

## Value

A tibble or named list, depending on the dataset. Use
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
to inspect the expected structure.

## Details

To restrict a time series to a date window, use `date_start` and
`date_end` or filter the returned `date` column with
[`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html).

## See also

[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md)
for large relational datasets,
[`list_datasets`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md)
for available datasets,
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
for dataset details,
[`clear_session_cache`](https://viniciusoike.github.io/realestatebr/reference/clear_session_cache.md)
to drop the in-session memo. For table and column documentation of each
dataset, see the dataset help topics:
[abecip](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[abrainc](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[bcb_realestate](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[bcb_series](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[fgv_ibre](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[pim_pf_construction](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[rppi](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[rppi_bis](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[secovi](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
and
[sinapi](https://viniciusoike.github.io/realestatebr/reference/sinapi.md).

## Examples

``` r
if (FALSE) { # interactive()
abecip_data <- get_dataset("abecip")

sbpe_data <- get_dataset("abecip", table = "sbpe")

bcb_data <- get_dataset("bcb_series", quiet = TRUE)

bcb_recent <- get_dataset(
  "bcb_series",
  date_start = as.Date("2020-01-01")
)
}
```
