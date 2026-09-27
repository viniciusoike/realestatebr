# PAIC implementation review

Reviewed the changes against `main` and [the PAIC plan](paic-dataset-plan.md) on 2026-09-27. **Recommendation: fix the state-level `size` values before merging.** The three-table structure, registry, and generated help follow the plan, but the data contract is not yet met.

## Important findings

1. **P1 — Unpublished state cells become zeros.** [IBGE table 10441](https://servicodados.ibge.gov.br/api/v3/agregados/10441/periodos/2024/variaveis/410?localidades=N3%5B35%5D&classificacao=319%5Ball%5D) returns `"-"` for São Paulo's `total` and `1_4` bands while reporting 20,878 firms in `5_plus`. `parse_ibge_value()` converts both dashes to zero, and `paic_value_status()` calls them `zero`. The plan also assumes every dash means absolute zero. **Suggested fix:** handle these unpublished cells in `clean_paic_size()` before publishing the table. Drop the affected state rows, document that state results cover `5_plus` only, and test the API pattern. Do not change the shared IBGE parser without checking its other callers.

2. **P1 — Partial responses can pass validation.** The PAIC validators check duplicate keys and minimum row counts, but not the expected variables, categories, years, or full set of states. `clean_paic_base()` also accepts a missing geography code. A response missing one state can therefore pass and enter the cache. **Suggested fix:** check coverage against the pinned crosswalk for each year and reject missing geography identifiers. Add a fixed 2024 SIDRA fixture that checks the national employment value and all 27 state rows, as the plan requires.

3. **P2 — The size-band test does not verify the identity.** `test-get-paic.R` supplies values that already sum to 1,000, then checks their sum. It also mixes the national total with division-41 rows. **Suggested fix:** test matching subtotal categories (`105185`, `8414`, `105187`, `105194`) and make `validate_paic_activity()` reject an inconsistent total, allowing for IBGE rounding where needed.

4. **P2 — The plan's retrieval checks remain unproved.** The tests inspect the registry but do not exercise `get_dataset("paic", table = "all", source = "fresh")`, the PAIC targets, or a fresh-versus-cached schema comparison. **Suggested fix:** run the PAIC target branch and compare one fresh result with its saved cache; keep a small fixture-based dispatch test in the package suite.

## Minor issues

- `_targets.R` defines `paic_validation` as a duplicate of `paic_activity_validation`.
- Empty API data produces a misleading wrong-table error in `clean_paic_base()`.
- Generated PAIC help contains doubled periods; `man/paic.Rd` has trailing whitespace.
- AIR would reformat `data-raw/pipeline/validation.R`; `tests/testthat/_snaps/get-paic.md` has an extra blank line at the end.

## Checks

`Rscript -e "devtools::test()"`: 320 passed, 0 failed, 0 warnings, 0 skipped. `Rscript -e "devtools::check(document = FALSE)"`: 0 errors, 0 warnings, 1 note for hidden `.git` and `.omx` directories. The roxygen arguments match `get_paic()`'s signature. `DESCRIPTION` adds no hard dependency. No fresh PAIC target or cache retrieval ran in this review.
