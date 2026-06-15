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
  [rppi](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
  [rppi_bis](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
  and
  [secovi](https://viniciusoike.github.io/realestatebr/reference/secovi.md).

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

  Date. Start date for time series filtering (where applicable).

- date_end:

  Date. End date for time series filtering (where applicable).

- ...:

  Additional arguments passed to internal dataset functions.

## Value

A tibble or named list, depending on the dataset. Use
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
to inspect the expected structure.

## See also

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
[rppi](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[rppi_bis](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[secovi](https://viniciusoike.github.io/realestatebr/reference/secovi.md).

## Examples

``` r
if (FALSE) { # interactive()
abecip_data <- get_dataset("abecip")

sbpe_data <- get_dataset("abecip", table = "sbpe")

bcb_recent <- get_dataset("bcb_series", date_start = as.Date("2020-01-01"))
}
```
