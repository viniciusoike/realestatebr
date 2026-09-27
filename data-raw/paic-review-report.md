# PAIC dataset review

Review of branch `t3code/implement-paic-dataset-plan` (commit `25f3a17`) against [the PAIC plan](paic-dataset-plan.md). Reviewed on 2026-09-27.

## Verdict

Do not merge yet. The `size` table reports unpublished state cells as zeros, and the tests do not check several of the plan's acceptance criteria. The code follows the plan's structure and package conventions, and the cached data pass hand checks.

## Checks run

| Check | Result |
|---|---|
| `devtools::test()` | 320 passed, 0 failed, 0 warnings, 0 skipped |
| `devtools::check(document = FALSE)` | 0 errors, 0 warnings, 1 note (hidden `.git` and `.omx` in the worktree; unrelated) |
| New dependencies | None |
| Roxygen for `get_paic()` vs signature | Match |
| National employment, table 10442, variable 631 | 2,181,647 in cache; matches the official API. The 27 states also sum to 2,181,647 |
| `activity` size-band identity (`total = 1_4 + 5_29 + 30_plus`) | Holds for all 89 variables in the cache |
| `activity` 30+ groups sum to divisions | Holds in the cache |
| `size` state cells, `total` and `1_4` bands | All 864 are `-` in SIDRA; the package returns them as zero (see issue 1) |

## Major issues

### 1. Unpublished state cells in `size` become zeros

In SIDRA table 10441, every state-level (N3) cell in the `total` and `1_4` bands is `-`. That is 864 of the table's 1,584 rows. The live API shows the pattern for São Paulo:

```
GET /agregados/10441/periodos/2024/variaveis/410?localidades=N3[35]&classificacao=319[all]
Total             "-"
1 a 4 pessoas     "-"
5 ou mais pessoas "20878"
```

São Paulo cannot have zero construction firms while 20,878 firms have five or more workers. Here `-` marks cells IBGE does not publish, not absolute zero. `parse_ibge_value()` maps `-` to `0`, and `paic_value_status()` labels the row `zero`. A user who sums `total` by state gets zero for every state.

The plan's premise that `-` always means absolute zero is wrong for this table. The registry repeats the claim in every `value` column description ("SIDRA dash (-) is absolute zero").

**Suggested fix.** Drop the unpublished rows in `clean_paic_size()`, then document and enforce the table's shape. The rows carry no information, so dropping them is simpler than inventing a new status.

```r
# SIDRA publishes state figures for firms with five or more workers only;
# "-" in the total and 1-4 bands marks unpublished cells, not zeros.
unpublished <- dat$geography_type == "state" &
  dat$size_band %in% c("total", "1_4")
dat <- dat[!unpublished, ]
```

Then do the following.

- Add a check to `validate_paic_size()` that fails if any state row has a size band other than `5_plus`.
- Add a test with a state `total` row whose `value_raw` is `-` and expect the row to be dropped.
- Update the `size` description in `inst/extdata/datasets.yaml` to say that state rows cover firms with five or more workers only. Regenerate `R/data-paic.R`.
- Reword the `value` column docs in all three tables. SIDRA's `-` means zero only where IBGE publishes the cell.

The two remaining zeros in state `5_plus` rows (variable 412 for Rondônia and Alagoas) look like genuine zeros; leave them.

Before merging, also scan the 239 zeros in `activity`. Most sit in 30+ class rows for third-party development costs, which are plausibly zero, but nobody has confirmed that against SIDRA.

### 2. The size-band identity test tests nothing

The test "PAIC activity size bands sum to the all-firm total" builds a fixture whose values already add up (600 + 300 + 100 = 1000), then asserts that they add up. It exercises no package logic. The fixture also mixes the national total (`105185`) with division-41 rows (`8415`, `8418`, `8432`), which does not reflect how the identity works: the total equals the sum of the size-band subtotals `8414`, `105187`, and `105194`.

The package does not enforce the identity at runtime either, even though the plan lists it as an acceptance criterion.

**Suggested fix.** Move the identity into `validate_paic_activity()`, where it runs on every download, and test that it fails on bad data.

```r
totals <- dat[dat$activity_level == "total", ]
wide <- tidyr::pivot_wider(
  totals[c("variable_id", "size_band", "value")],
  names_from = "size_band",
  values_from = "value"
)
gap <- abs(wide$total - (wide$`1_4` + wide$`5_29` + wide$`30_plus`))
if (any(gap > 1, na.rm = TRUE)) {
  cli::cli_abort("PAIC activity size bands do not sum to the all-firm total.")
}
```

The tolerance of 1 absorbs IBGE's rounding. If `tidyr` is not already in `Imports`, write the same check with `dplyr::summarise()` instead of adding a dependency.

Replace the current test with two tests. One feeds consistent subtotal rows (`105185`, `8414`, `105187`, `105194`) and expects no error. The other breaks one value and expects the abort.

### 3. No test uses real SIDRA values

The plan requires values and row counts from a fixed 2024 sample to match direct SIDRA queries, including 2,181,647 for national employment and a cross-check across all states. The current test types 2181647 into a synthetic tibble, so it proves only that the cleaner passes numbers through.

**Suggested fix.** Save a small slice of the real API response as a test fixture and assert against published figures.

1. Save the raw JSON for table 10442, variable 631, at N1 and N3 to `tests/testthat/fixtures/paic_10442_631.json`.
2. In the test, run the JSON through `parse_ibge_aggregate_chunk()`, `clean_paic_state()`, and `validate_paic_state()`.
3. Assert that the national value is 2,181,647, that there are 27 state rows, and that the state values sum to the national value.

Add one live test behind `skip_on_cran()` and `skip_if_offline()` that calls `get_paic("all")`. Check that the result is a named list of three tibbles with the registry's columns. The same test covers the missing dispatch and schema checks (issue 4).

### 4. Dispatch, cache, and error paths have no tests

No test calls `get_dataset("paic", table = "all")`, compares a fresh download's schema with the cached one, or routes through `get_dataset()`. The only PAIC dispatch test reads the registry.

Several error branches also have no tests: wrong `aggregate_id`, missing unit, unknown `size` category, and unknown geography level. The plan lists these under "Tests cover each symbol, duplicate keys, bad units, unexpected categories".

**Suggested fix.** Add one `expect_snapshot(error = TRUE, ...)` per branch, built with the existing `make_paic_raw()` helper. Cover the fresh-versus-cache schema with the live test from issue 3, using `get_dataset("paic", source = "cache")` where the release asset exists.

### 5. The Nota técnica research gate is not recorded as passed

The plan says to stop before implementation if the technical note cannot confirm the geography basis of variables 631, 673, 1245, and 1241 in table 10442. A code comment in `R/get_paic.R:516` quotes the note ("considerando o local de atuação das empresas"), but nothing records that someone read and confirmed it.

**Suggested fix.** Confirm the basis from the note. Then add one line to the plan or the registry's `translation_notes` naming the note, its date, and the confirmed basis for each variable.

### 6. Empty or malformed API responses give misleading errors

When the response has zero rows, `unique(raw$aggregate_id)` is `character(0)`, and `clean_paic_base()` aborts with "PAIC response is not from SIDRA table …". When a classification column is missing, `raw$classification_12296_code` is `NULL`, so the lookups return zero-length vectors instead of failing with a clear message.

**Suggested fix.** Add an early check at the top of `clean_paic_base()`.

```r
if (nrow(raw) == 0) {
  cli::cli_abort("PAIC response for SIDRA table {.val {expected_table}} is empty.")
}
```

In `clean_paic_activity()` and `clean_paic_size()`, abort if the expected `classification_*_code` column is absent.

## Minor issues

- `_targets.R`: the `paic_validation` target repeats `paic_activity_validation` and appears twice in the validations summary. Delete it.
- `inst/extdata/datasets.yaml`: the `activity` description ends with a period, so the generated `R/data-paic.R` reads "size bands.. This is the default table."
- `R/get_paic.R:828`: `|` inside `if()`; use `||`.
- `R/get_paic.R:712`: redundant, because `substr(NA, 1, 2)` already returns `NA`.
- English variable names are inconsistent across tables: `other_costs_total` (1280) vs `other_costs` (1238), and `construction_costs` covers both 1236 ("Total de custos…") and 1245. The different underlying concepts invite wrong joins.
- The three `validate_paic_*()` functions repeat the same duplicate-key and missing-unit checks; one helper taking `keys` would remove the repetition.
- `paic_value_status()` matches `"X "` with a trailing space. Trim `value_raw` once instead.
- The 180-day `tar_cue_age` refetches the data about twice a year for an annual survey released around June. That is harmless, but it only approximates the release schedule the plan asked to match.

## Plan coverage

**Done:**
- Three tables mapped to SIDRA 10463, 10441, and 10442.
- Category and variable crosswalks keyed by ID, with unknown IDs failing.
- A package-owned CNAE 2.0 lookup.
- A `value_status` column.
- A `geography_basis` column set per variable.
- The 10441 share variables dropped.
- `default_table: "activity"`.
- Registry entry, generated help, pkgdown index, targets wiring, and NEWS entry.

**Beyond the plan:** all 89 variables in table 10463 got English identifiers, where the plan asked for about 15 core measures.

**Not met:**
- The documented source semantics for `-` (issue 1).
- A runtime and tested size-band identity (issue 2).
- A fixed SIDRA sample (issue 3).
- Dispatch and cache-schema tests (issue 4).
- A recorded Nota técnica gate (issue 5).
