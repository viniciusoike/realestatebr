# Process BIS Detailed CSV Data

Reads the flat CSV, parses compound columns, then splits by frequency
with appropriate date parsing for each.

## Usage

``` r
clean_bis_detailed(csv_path, quiet)
```

## Arguments

- csv_path:

  Path to the extracted CSV file

- quiet:

  Logical controlling messages

## Value

Named list with elements: monthly, quarterly, annual, halfyearly
