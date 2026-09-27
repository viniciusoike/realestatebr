# PAIC dataset plan

## Requirements summary

Add the Pesquisa Anual da Indústria da Construção (PAIC) to `realestatebr` as an annual IBGE dataset covering construction enterprises, employment, revenue, costs, and output. The [dataset roadmap](realestatebr-dataset-roadmap.md) rates PAIC as a core release item, but places MCMV and PNAD Housing ahead of it. This plan defines the PAIC work; it does not change that release order.

**First-release scope:** use the new PAIC series from reference year 2024 onward. Plan 2007–2023 as a separate historical phase. IBGE marks 2024 as a new series and [publishes 2024 onward in SIDRA only](https://www.ibge.gov.br/estatisticas/economicas/industria/9018-pesquisa-anual-da-industria-da-construcao.html?=&t=resultados). Do not silently join the two series or report a 2023–2024 growth rate.

The package already has an [IBGE aggregate downloader](../R/ibge_aggregates.R), a [SINAPI adapter pattern](../R/get_sinapi.R), a [dataset registry](../inst/extdata/datasets.yaml), [generated dataset help](generate_dataset_docs.R), and a [targets update pipeline](../_targets.R). Reuse these surfaces.

## Source and data contract

1. Use the [official PAIC SIDRA catalogue](https://sidra.ibge.gov.br/pesquisa/paic/tabelas) and the [IBGE aggregate API](https://servicodados.ibge.gov.br/api/docs/agregados?versao=3). The API returned 2024 data when checked on 2026-09-27; 2024 was the latest reference year at that check.
2. The first release uses three new-series tables, each mapped to one package table. Add 6667 (activity by size), 10173 (products), and coefficient-of-variation tables only if a concrete user-facing use case warrants them.

   | Package table | SIDRA table | Geography | Dimensions | Firms |
   |---|---|---|---|---|
   | `activity` | [10463](https://servicodados.ibge.gov.br/api/v3/agregados/10463/metadados) | Brazil | size band × CNAE activity | all |
   | `size` | [10441](https://servicodados.ibge.gov.br/api/v3/agregados/10441/metadados) | Brazil, regions, states | size band | all |
   | `state` | [10442](https://servicodados.ibge.gov.br/api/v3/agregados/10442/metadados) | Brazil, regions, states | none | 5+ workers |

3. PAIC fits the existing contract without an exception: each table returns one tibble, and `table = "all"` returns a named list, as in `abecip`. Set `default_table: "activity"`.
4. Publish observed values with original units, including **thousand reais** where specified by IBGE. The existing [parser](../R/ibge_aggregates.R) maps `-` to zero, which matches SIDRA's meaning (absolute zero) in tables 10463 and 10442. Table 10441 is an exception: SIDRA uses `-` for every state cell in the total and 1–4 bands, which IBGE does not publish (São Paulo shows `-` firms in total and 20,878 with five or more workers). The adapter drops those rows, so state rows in `size` cover the 5+ band only. It maps `..` (not applicable), `...` (not available), and `X` (suppressed) all to `NA`, so derive a `value_status` column from `value_raw` to keep them apart. The parser needs no change.
5. Read IBGE's *Nota técnica 01/2026* on PAIC's sample and presentation changes before finalizing variable selection or any cross-series comparison. The [IBGE PAIC results page](https://www.ibge.gov.br/estatisticas/economicas/industria/9018-pesquisa-anual-da-industria-da-construcao.html?=&t=resultados) links it, but the note was inaccessible during this planning pass. Treat that as a research gate. In particular, confirm whether the state breakdown of variables 631, 673, 1245, and 1241 in table 10442 follows headquarters or work location. **Resolved 2026-09-27:** the [PAIC 2024 publication](https://biblioteca.ibge.gov.br/visualizacao/periodicos/54/paic_2024_v34.pdf) (v. 34, June 2026), which summarizes the note, says the regional block collects these variables by "Unidade da Federação de atuação da empresa". All four, and 13808, follow work location; 13807 follows headquarters.

## Table layout

PAIC's hierarchy lives in its classification codes, not in the data structure. Flatten each table into a long tibble with the hierarchy as explicit columns; users filter by level to avoid double-counting. Common columns are `year` (integer), `source_table`, `geography_type`, `geography_code`, `geography_name`, `variable_id`, `variable`, `variable_name_pt`, `unit`, `value`, `value_raw`, and `value_status`.

**`activity` (table 10463).** Classification 12296 fuses firm size and CNAE activity into one list of 52 categories, and IBGE's `nivel` field does not track the CNAE level: division 42, group 42.2, and class 42.21 all have `nivel = 2`. Parse both dimensions from the category label instead.

- `size_band`: `total`, `1_4`, `5_29`, `30_plus`, parsed from the label text.
- `activity_level`: `total`, `division`, `group`, or `class`, from the number of digits in the CNAE code.
- `activity_code`, `division_code`, `group_code`: the CNAE code parsed from the label prefix, plus its parent codes.
- `activity_name`: from a package-owned CNAE 2.0 lookup keyed by code. IBGE's labels carry typos ("infraestrtutura") and inconsistent suffixes ("- total", "- subtotal").

Detail depth differs by size band: 1–4 workers reaches divisions only, 5–29 adds groups, and 30+ reaches classes. No category covers all sizes for a single division; the only all-firm row is "Total das empresas". A national division total is therefore the sum of the three size bands. Document this in the registry.

**`size` (table 10441).** Keep the 16 level variables and drop the 16 share variables (IDs `1000xxx`, "percentual do total geral"), which users can derive. `size_band` takes `total`, `1_4`, and `5_plus`.

**`state` (table 10442).** The table mixes geography bases: variable 13807 counts firms by headquarters state, and 13808 counts firms active in each state (Rondônia: 335 versus 418). Add a `geography_basis` column (`headquarters` or `work_location`) set per variable from the crosswalk, not per table.

## Acceptance criteria

- `get_dataset("paic", table = ..., source = "fresh")` returns one tibble for each of `activity`, `size`, and `state`; `table = "all"` returns a named list. `get_dataset_info("paic")` documents each table's grain, units, scope, size-band coverage, and the 2024 series break. The registry follows the structure at [datasets.yaml:214](../inst/extdata/datasets.yaml), and the dispatch follows [get_dataset.R:94](../R/get_dataset.R).
- Every retained row has a reference year, source table, variable ID, unit, geography, and all relevant classification fields. The key is unique within its table. Unknown variable or category IDs fail validation rather than acquiring guessed labels.
- A checked-in source crosswalk lists every retained variable ID with its Portuguese label, unit, source table, and, for `state`, geography basis. Table 10463 keeps all 89 variables; core measures (about 15, covering firms, employment, wages, costs, revenue, gross output, and value added) also get English identifiers.
- Numeric values and row counts for a fixed 2024 sample match direct SIDRA queries. Include national employment in table 10442, variable 631, as one fixture: the [official API returned 2,181,647](https://servicodados.ibge.gov.br/api/v3/agregados/10442/periodos/2024/variaveis/631?localidades=N1%5Ball%5D) for firms with five or more workers when checked on 2026-09-27. Cross-check the full UF set, not only one value.
- In `activity`, the three size bands sum to the all-firm total at division level, every 30+ class maps to a group and division, and the parsed CNAE codes match the lookup.
- Missing, suppressed, and zero observations follow documented source semantics. Tests cover each symbol, duplicate keys, bad units, unexpected categories, and the per-variable geography basis in `state`.
- The `targets` pipeline downloads, validates, and caches PAIC; the generated help topic and public dataset list show the same table names and columns. A fresh run and a cached read return the documented schema.

## Implementation steps

1. **Confirm new-series source mappings.** Read the 2026 technical note about the 2024 series. Pin variable selections, the geography basis for each `state` variable, and the size-band/CNAE parsing of classification 12296 in a small, checked-in crosswalk built from live table metadata. Add the CNAE 2.0 lookup for divisions 41–43. Keep legacy tables out of the first-release adapter.
2. **Write tests first.** Add fixtures and contract tests in `tests/testthat/test-get-paic.R` for source parsing, category-label parsing, the three table grains, units/status, the size-band identity, validation errors, and registry dispatch. Use the existing [IBGE parser tests](../tests/testthat/test-ibge_aggregates.R) as the lower-level baseline.
3. **Implement the adapter.** Add `R/get_paic.R`, calling `download_ibge_aggregate()` from [ibge_aggregates.R:6](../R/ibge_aggregates.R) with explicit variables, periods, localities, and classifications. Keep transformations and validation separate, following [get_sinapi.R:52](../R/get_sinapi.R). Avoid another HTTP client or package dependency.
4. **Register and document.** Add the three PAIC tables, columns, source URLs, annual frequency, release lag, size-band coverage, and 2024 break to `inst/extdata/datasets.yaml`. Generate `R/data-paic.R` with [generate_dataset_docs.R](generate_dataset_docs.R), run `devtools::document()`, and update package-facing help or README references that enumerate datasets.
5. **Wire refresh and verify.** Add PAIC data/cache/validation targets and summary entries beside [SINAPI targets](../_targets.R). Run the PAIC target branch, targeted tests, package checks, and a fresh-versus-cached retrieval smoke test. Check that the annual refresh cue matches IBGE's release schedule rather than copying the weekly SINAPI cue.

## Risks and mitigations

- **2024 break:** label the new series; keep legacy data in a separate table or explicit `series` field if added later. No automatic growth rates across the break.
- **Double-counting:** `activity` stacks totals, divisions, groups, and classes in one tibble. Document the `activity_level` filter in the help topic and examples.
- **Label drift:** IBGE may edit category labels between releases. Parse codes by category ID through the crosswalk, and fail on unknown IDs.
- **Geographic meaning:** record the geography basis per variable and the 5+ worker threshold of `state` in metadata and tests.
- **Source revisions:** record retrieval time and source table IDs. IBGE has [revised historical PAIC figures](https://ftp.ibge.gov.br/Industria_da_Construcao/Pesquisa_Anual_da_Industria_da_Construcao/comunicado_paic_20210611.txt); make a full refresh reproducible.
- **Large/fragile requests:** query explicit metric sets and table dimensions, split large requests if needed, and compare returned year/geography/category coverage against live metadata.

## Later historical phase

Map [1741](https://servicodados.ibge.gov.br/api/v3/agregados/1741/periodos), [1757](https://servicodados.ibge.gov.br/api/v3/agregados/1757/metadados), [1761](https://servicodados.ibge.gov.br/api/v3/agregados/1761/metadados), and any other required 2007–2023 tables one measure at a time. Document comparability against the 2024 series; do not infer equivalence from variable IDs or similar labels. Ship history as a distinct series, without an automatic growth rate across 2023–2024.

## Verification and stop condition

Stop when the selected scope is documented, all targeted tests pass, the PAIC targets produce a validated cache, the help and registry agree, and direct IBGE values match the package output for a fixed sample. If the technical note or variable crosswalk cannot be verified, stop before implementation and resolve that source definition first.
