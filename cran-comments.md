## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes

### Possibly mis-spelled words in DESCRIPTION
Any flagged words (e.g., ABECIP, ABRAINC, SECOVI, FGV, IBGE) are proper names
and acronyms for Brazilian real estate institutions and are spelled correctly.

### URLs using HTTP
The CBIC data source (www.cbicdados.com.br) does not support HTTPS. This is a
third-party limitation outside our control. All other URLs use HTTPS.

## Vignettes

Both vignettes use `eval = FALSE` globally. All examples require active
internet connections to external Brazilian government and institutional data
sources. This approach is standard practice for data-access packages (e.g.,
tidycensus, rnaturalearth). The vignettes build successfully and provide
complete working code for users to run interactively.

## Network Access in Tests

All tests requiring network access use `testthat::skip_on_cran()` or
`testthat::skip_if_offline()`. Integration tests are explicitly skipped on CRAN.

## Test Platforms

- macOS (local): 0 errors, 0 warnings
- [Add rhub::check_for_cran() results before submission]
