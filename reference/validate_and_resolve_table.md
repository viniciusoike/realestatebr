# Validate and Resolve Table Parameter

Validates table parameter against available tables and resolves default
table

## Usage

``` r
validate_and_resolve_table(name, dataset_info, table = NULL)
```

## Arguments

- name:

  Dataset name

- dataset_info:

  Dataset metadata from registry

- table:

  User-specified table name (can be NULL)

## Value

List with resolved_table, available_tables, and is_default
