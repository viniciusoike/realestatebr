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
