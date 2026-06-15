# Get Dataset from Specific Source

Internal function to get data from a specific source type.

## Usage

``` r
get_dataset_from_source(
  name,
  dataset_info,
  source,
  table,
  date_start,
  date_end,
  ...
)
```

## Arguments

- name:

  Dataset name

- dataset_info:

  Dataset metadata

- source:

  Source type ("cache", "github", "fresh")

- table:

  Optional table

- date_start:

  Optional start date

- date_end:

  Optional end date

- ...:

  Additional arguments

## Value

Dataset or error
