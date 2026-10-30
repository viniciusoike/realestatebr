# Build the published `siconfi_taxes` table

`finbra` and `api` are parsed long forms (source `finbra` and `api`
respectively); `municipalities` holds the municipality universe as a
tibble with integer 7-digit `code_muni` and `abbrev_state`. `population`
holds the IBGE municipality-year population as a tibble (`code_muni`,
`year`, `population`, `population_source`); NULL publishes all NA. API
rows replace FINBRA rows for the whole municipality-year so the per-row
`source` stays unambiguous. Non-reporters get one row per tax with
`reported = FALSE` and NA tax and revenue values (population does not
depend on reporting). A gross row with no deduction row in the source
counts the deduction as zero: `other_deductions` becomes 0, the net is
computed, and `deductions_reported` marks the assumption (FALSE assumed,
TRUE observed, NA when there is no gross row). Keys with a deduction row
but no gross row keep `gross_revenue` and `net_revenue` NA.

## Usage

``` r
build_siconfi_taxes(
  finbra,
  api = NULL,
  municipalities,
  population = NULL,
  call = caller_env()
)
```
