# Validate the built `siconfi_taxes` table

Checks the published schema (column names, order and types for every
column), integer 7-digit municipality codes, unique code_muni x year x
tax keys, the documented `tax`, `value_status`, `account_scope` and
`population_source` domains, NA values and source on non-reporter rows
(population is exempt: it is independent of reporting, with its source
NA exactly when it is NA), and the gross-minus-deductions net identity.

## Usage

``` r
validate_siconfi_taxes(data, call = caller_env())
```
