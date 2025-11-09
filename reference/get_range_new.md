# Get Excel Range for Data Extraction

Determines the exact range of cells containing data in an Excel sheet.
The function finds the boundaries of the data by identifying the last
row containing dates and the last column containing non-NA values.

## Usage

``` r
get_range_new(path = NULL, sheet, skip_row = 4)
```

## Arguments

- path:

  Character string. Path to the Excel file.

- sheet:

  Character string. Name of the sheet to analyze.

- skip_row:

  Numeric. Number of rows to skip before the actual data begins.
  Defaults to 4.

## Value

Character string representing an Excel range (e.g., "B5:BD162").

## Details

The function works by:

1.  Reading the Excel sheet

2.  Identifying columns containing dates

3.  Finding the last row with valid dates

4.  Finding the last column with non-NA values

5.  Converting column numbers to Excel-style letters

6.  Constructing the range string

## Examples

``` r
if (FALSE) { # \dontrun{
# Get range from a specific sheet
range <- get_range("path/to/file.xlsx", sheet = "Sheet1", skip_row = 4)
print(range) # Returns something like "B5:BD162"
} # }
```
