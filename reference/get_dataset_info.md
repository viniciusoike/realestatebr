# Get Dataset Information

Get detailed metadata for a specific dataset including available
categories and column descriptions.

## Usage

``` r
get_dataset_info(name)
```

## Arguments

- name:

  Character. Name of the dataset (use list_datasets() to see available
  names)

## Value

A list with detailed dataset information including:

- metadata:

  Basic dataset information

- categories:

  Available categories/subtables

- source_info:

  Data source details

## Examples

``` r
if (FALSE) { # \dontrun{
# Get detailed info for ABECIP indicators
info <- get_dataset_info("abecip")
str(info)
} # }
```
