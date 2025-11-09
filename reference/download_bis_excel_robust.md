# Download BIS Excel File with Robust Error Handling

Internal function to download BIS Excel files with retry logic.

## Usage

``` r
download_bis_excel_robust(url, filename, quiet, max_retries)
```

## Arguments

- url:

  URL to download from

- filename:

  Filename for temporary file

- quiet:

  Logical controlling messages

- max_retries:

  Maximum number of retry attempts

## Value

Path to downloaded temporary Excel file
