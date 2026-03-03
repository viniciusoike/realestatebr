# Process BIS Selected CSV Data

Reads the column-oriented CSV from the BIS SPP dataset, pivots date
columns to long format, and standardises column names.

## Usage

``` r
process_bis_selected_data(csv_path, quiet)
```

## Arguments

- csv_path:

  Path to the extracted CSV file

- quiet:

  Logical controlling messages

## Value

Processed BIS selected data tibble
