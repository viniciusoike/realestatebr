# Update Cache from GitHub

Updates local cache for specific datasets if GitHub has newer versions.

## Usage

``` r
update_cache_from_github(dataset_names = NULL, quiet = FALSE)
```

## Arguments

- dataset_names:

  Character vector. Datasets to update, or NULL for all

- quiet:

  Logical. Suppress messages

## Value

Named logical vector indicating success/failure for each dataset

## Examples

``` r
# \donttest{
# Update specific datasets
update_cache_from_github(c("abecip", "bcb_series"))
#> Updating abecip from GitHub...
#> Attempting to download abecip.rds from GitHub...
#> Warning: file(s) abecip.rds not found in repo "viniciusoike/realestatebr"
#> ℹ All local files already up-to-date!
#> Attempting to download abecip.csv.gz from GitHub...
#> Warning: file(s) abecip.csv.gz not found in repo "viniciusoike/realestatebr"
#> ℹ All local files already up-to-date!
#> Error in download_from_github_release(dataset, overwrite = TRUE, quiet = quiet): Dataset 'abecip' not found on GitHub releases
#> ℹ Available datasets: abecip_sbpe.rds, abecip_units.rds, abrainc_indicator.rds,
#>   abrainc_leading.rds, abrainc_radar.rds, bcb_realestate.rds, bcb_series.rds,
#>   bis_selected.rds, fgv_ibre.rds, rppi_rent.rds, rppi_sale.rds, secovi_sp.rds
#> ℹ Or use source='fresh' to download from original source

# Update all cached datasets
update_cache_from_github()
#> Found 5 cached files
#> Skipping cache_metadata: cannot determine if update needed
#> Skipping rppi_sale: already up to date
#> Skipping bcb_series: already up to date
#> Skipping bcb_realestate: already up to date
#> Skipping abecip_sbpe: already up to date
#> Updated 4 datasets
#> cache_metadata      rppi_sale     bcb_series bcb_realestate    abecip_sbpe 
#>             NA           TRUE           TRUE           TRUE           TRUE 
# }
```
