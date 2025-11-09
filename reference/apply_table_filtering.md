# Apply Table Filtering to Loaded Dataset

Applies table/category filtering logic for datasets that support
multiple tables. Used by both get_from_local_cache() and
get_from_github_cache().

## Usage

``` r
apply_table_filtering(data, name, table)
```

## Arguments

- data:

  Dataset to filter

- name:

  Dataset name

- table:

  Table name to filter by (or NULL)

## Value

Filtered dataset
