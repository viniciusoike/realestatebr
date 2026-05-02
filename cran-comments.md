## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes

### Possibly mis-spelled words in DESCRIPTION
Any flagged words (e.g., ABECIP, ABRAINC, SECOVI, FGV, IBGE) are proper names
and acronyms for Brazilian real estate institutions and are spelled correctly.

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

- macOS (local): 0 errors, 0 warnings, 0 notes
- Windows R-devel (win-builder, 2026-05-02): 0 errors, 0 warnings, 1 note

### Notes on win-builder results

**NOTE: New submission** — Expected for first CRAN submission.

**NOTE: Possibly mis-spelled words** — ABECIP, ABRAINC, BCB, FGV, and SECOVI
are official acronyms for Brazilian real estate and financial institutions.
They are spelled correctly.
