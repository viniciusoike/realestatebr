## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Response to CRAN reviewer feedback

* **Acronyms in Description**: Expanded all acronyms on first mention — BCB
  (Central Bank of Brazil), ABRAINC (Brazilian Association of Real Estate
  Developers), ABECIP (Brazilian Association of Real Estate Credit and Savings
  Entities), FGV (Getulio Vargas Foundation), BIS (Bank for International
  Settlements).

* **Webservice links**: Added `<https://...>` links for all referenced data
  providers directly in the Description field of DESCRIPTION.

* **Examples for unexported functions**: Removed the example from `get_range()`.
  The function now uses `@noRd` and no longer generates an Rd file.

* **`\dontrun{}`**: Replaced with `@examplesIf interactive()` throughout all
  exported function documentation. Examples that require network access or modify
  the file system are guarded with `@examplesIf interactive()` instead of
  `\dontrun{}`. Examples that only read bundled package data (e.g.,
  `list_datasets()`, `get_dataset_info()`) run unconditionally.
