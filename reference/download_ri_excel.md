# Download Excel File with Retry Logic for Registro de Imoveis

Internal helper function to download Excel files with retry attempts.

## Usage

``` r
download_ri_excel(url, filename, quiet, max_retries)
```

## Arguments

- url:

  Download URL

- filename:

  Base filename for temp file

- quiet:

  Logical controlling messages

- max_retries:

  Maximum retry attempts

## Value

List with path (character or NULL) and attempt count
