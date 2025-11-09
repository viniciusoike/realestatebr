# Get Dataset with Fallback Strategy

Internal function implementing the auto fallback strategy: cache →
GitHub → fresh download

## Usage

``` r
get_dataset_with_fallback(name, dataset_info, table, date_start, date_end, ...)
```

## Arguments

- name:

  Dataset name

- dataset_info:

  Dataset metadata from registry

- table:

  Optional table filter

- date_start:

  Optional start date

- date_end:

  Optional end date

- ...:

  Additional arguments

## Value

Dataset or NULL if all methods fail
