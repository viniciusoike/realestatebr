# Attach Standard Metadata to Dataset

Attaches standardized metadata attributes to a dataset. Consolidates
metadata attachment logic used across all dataset functions.

## Usage

``` r
attach_dataset_metadata(
  data,
  source = c("web", "cache", "github"),
  category = NULL,
  extra_info = list()
)
```

## Arguments

- data:

  Data frame or tibble. The dataset to attach metadata to.

- source:

  Character. Data source: "web", "cache", or "github".

- category:

  Character or NULL. Dataset category/table name.

- extra_info:

  List. Additional metadata to include in download_info.

## Value

The data with metadata attributes attached.

## Details

Attaches three standard attributes:

- `source`: Where the data came from ("web", "cache", "github")

- `download_time`: Timestamp when data was retrieved

- `download_info`: List with source, category, and any extra_info

The metadata is preserved when subsetting but may be lost during some
transformations. Use
[`attributes()`](https://rdrr.io/r/base/attributes.html) to inspect
metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
data <- attach_dataset_metadata(
  data,
  source = "web",
  category = "sbpe",
  extra_info = list(attempts = 1, url = "https://...")
)

# Inspect metadata
attributes(data)$source # "web"
attributes(data)$download_time # POSIXct timestamp
attributes(data)$download_info # List with details
} # }
```
