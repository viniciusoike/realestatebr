# FGTS/MCMV implementation plan

Investigated on 2026-09-15; revised after inspecting the July 2026 financing and June 2026 subsidized-project downloads. This document proposes implementation; it does not register or publish a dataset.

Use the existing CNO query infrastructure for a new `mcmv` catalog. Publish separate Parquet tables for financing records, the official financing summary, and subsidized housing project records. Preserve source observations and labels, including records outside MCMV/CVA and repeated project records. Explain those limitations in the dataset documentation.

## Fresh local extracts and revised baseline

The new July financing pair and June subsidized-project file are the proposed initial release inputs. All three were scanned completely as UTF-8 semicolon-delimited CSVs, with no inconsistent field counts and no parse failures in the profiled numeric fields or signature dates. These are inspected local downloads; their identity with the current online assets has not been independently verified.

| File | Rows | Columns | Reference date | Signature coverage / summary period |
|---|---:|---:|---|---|
| `mcmv_financ_analitico_20260724.csv` | 7,849,882 | 21 | 2026-07-24 | 2009-01-02 through 2026-07-23 |
| `mcmv_financ_sintetico_20260724_v2.csv` | 795,684 | 11 | 2026-07-24 | 2009–2026, with month and income band |
| `mcmv_subsidiado_20260630.csv` | 26,111 | 21 | 2026-06-30 | 2009-02-27 through 2026-06-23 |

The July analytical CSV occupies 1,295,750,523 bytes, the summary 62,818,037 bytes, and the subsidized-project CSV 5,443,137 bytes. Analytical and project amounts use Brazilian numeric notation; summary amounts use decimal points. The project file also formats municipality codes with a thousands separator, despite retaining the earlier headers.

### July financing findings

- Every analytical row reports one unit, totaling 7,849,882. Signature dates are present throughout. Six rows lack municipality, state, and region; all nonmissing municipality codes have six digits.
- Birth date and project name are absent from the schema; sex is present again. Sex values are `M`, `F`, `X`, or blank, with 365,992 blanks.
- Income bands are source codes `1`, `2`, `3`, and `4`, plus 216,142 blanks. Do not interpret blanks as outside MCMV or translate code `4` without an authoritative mapping. The older dictionary does not define these codes.
- Program labels include 127,594 `Fundo Social` rows and 27,406 `Classe Média` rows. Preserve the separate income-band field and source program labels rather than equating them.
- `bln_cotista` mixes `S`, `N`, `1`, `0`, and blanks; 7,407,240 rows are blank. Keep it as character and report missingness instead of coercing it to Boolean.
- Property-type labels mix upper, lower, and title case, with 6,565 blanks. There are 1,097 missing purchase values and 11,198 missing values in each interest-subsidy component.
- Numeric ranges include household income up to BRL 1,674,140.71, financing up to BRL 1,500,000, and interest rates from 0 to 10. Retain these observations and report extremes; this inspection does not establish their economic validity.

### Reconciliation of the July pair

The summary is unique by municipality/year/month/income band, treating blank values as explicit groups for comparison. Both inputs produce exactly the same 795,684 groups, including the six observations without geography. There are no unmatched groups. Unit counts agree exactly in every group; financing values agree within BRL 0.01 per group. The summary reports approximately BRL 894.434 billion in financing.

The summary subsidy agrees within BRL 0.01 in every group with the sum of the four analytical components: FGTS discount, OGU discount, FGTS interest subsidy, and OGU interest subsidy. Comparing only discount subsidies fails in 526,016 groups. Document this as an observed relationship for this release, and test it on subsequent releases rather than assuming the same definition forever. Component sums use available numeric values for this audit; source NULLs remain NULL in published records.

Reconciliation used floating-point arithmetic and a per-group tolerance. Do not claim byte-exact monetary equality or use naive grand-total equality as a publication check.

### June subsidized-project findings

The file has 3,281 exact duplicate rows, 4,608 missing operation codes, and 3,261 repeated occurrences beyond the first among nonmissing operation codes. Operation code remains unsuitable as a primary key. The source reports 2,168,225 contracted units including repeated records; this is not a deduplicated program total.

All 26,105 rows with complete unit components satisfy contracted = delivered + outstanding + cancelled. Six rows have missing cancelled units and must be marked incomplete, even though treating those missing values as zero also balances their totals. Preserve NULLs rather than imputing zero. This replaces the older extract's 527 observed discrepancies without changing the policy of retaining source records.

### Downloaded dictionaries

`Dicionarios_SNH_2025_10_09.pdf` and `Dicionarios_SNH_2025_10_09-2.pdf` are byte-identical (SHA-256 `2984db412aa6cc7d251766fcc7921b5e2bd7ff62f82e1782a69ca3f6d1269c86`). Both remain version 2.4 dated 2025-10-09. Their financing pages still describe an eight-column annual summary and a 23-column analytical layout. They do not document the new monthly summary, coded income bands, removed analytical columns, or mixed account-holder codes. Retain the dictionary as a semantic reference and record these divergences explicitly.

## Earlier local extracts

Files are in `data-raw/backlog/fgts/`. All four distinct CSVs use semicolon delimiters and were read completely as UTF-8.

| Source | Observed structure | Reference date inside file |
|---|---|---|
| `dados_abertos_FGTS_ANALITICO_202512.rar` | One CSV, 1,336,703,136 uncompressed bytes; 7,390,483 rows; 23 columns; Brazilian numeric notation | 2025-12-05 |
| `view_dados_abertos_fgts_detalhado_202603201548.zip` | One CSV, 1,374,888,442 uncompressed bytes; 7,486,769 rows; 22 columns; decimal-point numbers | 2026-03-13 |
| `dados_abertos_FGTS_SINTETICO_202512.csv` | 61,599 rows; 8 columns; Brazilian numeric notation | 2025-07-11 |
| `view_dados_abertos_ogu_202603201556.csv` | 25,888 rows; 21 columns; decimal-point numbers | 2025-12-31 |
| `view_dados_abertos_ogu_202603201556.zip` | Contains a byte-identical copy of the standalone OGU CSV | Same as above |

All four distinct CSVs have no inconsistent field counts. Filenames and extraction timestamps do not identify the observation reference date reliably.

The legacy analytical extract covers signature dates from 2009-03-02 through 2025-12-04. All rows report one financed unit; six lack municipality and state fields. It includes `Classe Média` and `Fundo Social` program labels absent from the March extract, and uses different income-band and property-type labels. A newer extraction date does not prove equivalent coverage. Compare aggregates and source definitions before describing the March file as a complete successor. Neither extract supports record-level linkage across versions.

The March financing extract covers signature dates from 2005-11-17 through 2026-03-12, with 1,275 missing signature dates. All rows report one financed unit. It includes 494,268 records labeled `Fora MCMV/CVA`. Project name is empty in every row. Purchase value is missing in 624,872 rows, interest rate in 516,892, and birth date in 3,268,304. Preserve missingness and the source's `X` category codes.

The summary reports 7,133,329 financed units. Municipality/year combinations are unique when missing years are treated as a group; 147 rows lack a year. Observed nonmissing years span 2005–2025. The file has no program dimension despite the landing page's description. Its earlier reference date prevents a strict reconciliation to either local analytical extract.

OGU signature dates span 2009-02-27 through 2025-12-30. There are 84 missing operation codes, 3,263 duplicate occurrences beyond the first among nonempty operation codes, and 3,261 exact duplicate rows. Adding municipality and modality does not produce a unique key. For 527 rows, contracted units differ from delivered plus outstanding plus cancelled units. These are source findings to report, not reasons to silently delete or alter observations.

## Source contract

The [Ministry landing page](https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/bases-de-dados-do-programa-minha-casa-minha-vida) supplies the financing and subsidized-project sources and describes publication as at least quarterly. Its current description includes FGTS and Fundo Social financing. Treat the local files as dated inputs, not a verified copy of the latest release.

The [official dictionary](https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/minha-casa-minha-vida-fnhis-sub-50-1/arquivos-fnhis-sub-50/Dicionarios_SNH_2025_10_09.pdf) identifies analytical municipality codes as six-digit IBGE codes without the check digit. It lists a sex field absent from the March extract. Verify actual headers for every acquisition rather than treating the dictionary as an exact file schema.

## Public interface and tables

```r
mcmv <- query_dataset("mcmv")

result <- mcmv$financing |>
  dplyr::filter(state == "SP", income_band == "1") |>
  dplyr::group_by(code_muni_6) |>
  dplyr::summarise(units_financed = sum(units_financed), .groups = "drop") |>
  dplyr::collect()

close(mcmv)
```

| Table | Grain and role |
|---|---|
| `financing` | One published financing observation. No source contract identifier or declared unique key. |
| `financing_summary` | Official municipality/year/month/income-band totals in the July 2026 layout, retaining the original reference date. Not calculated from `financing`. |
| `subsidized_projects` | One published OGU project record. Operation code is not a primary key. |

Use the July 2026 financing files and June 2026 subsidized-project file for the initial build. Keep earlier extracts as historical evidence and parser fixtures. Do not append the legacy, March, and July financing files. They are overlapping full extracts and should become separate immutable versions if both are published. Do not join financing to OGU using project names. Municipality aggregates can be compared only with explicit treatment of dates, coverage, and source duplicates.

Keep all tables under query access for a consistent interface. A separate materialized summary API is unnecessary for the initial release. OGU supports the roadmap's project and delivery scope; financing alone does not.

## Proposed normalized schema

Use measure-family prefixes consistently: `units_*` for housing counts, `amount_*` for financed, contracted, and disbursed amounts, and `subsidy_<funding source>_<component>` for subsidy components. Use `code_muni_6` for the six-digit IBGE municipality code without its check digit and `name_muni` for the source municipality name. Keep `state` and `region` consistent across the three tables.

Use `contract_date`, `contract_year`, and `contract_month` for the contracting event, and retain `reference_date` for the source snapshot. Keep natural names such as `purchase_price`, `household_income`, and `interest_rate`. Use `responsible_entity_name` and `responsible_entity_cnpj` because the source covers both construction companies and social entities. Source headers and category values remain unchanged in the input adapters.

Use English column names, character identifiers and labels, `DATE` dates, `INTEGER` unit counts and years, and `DOUBLE` monetary amounts and interest rates. `DOUBLE` preserves the published fractional values without imposing an unrequested rounding rule. Amounts remain nominal BRL; rates retain source percentage units without assuming an undocumented periodicity.

### Financing

| Source field | Output field | Type |
|---|---|---|
| `data_referencia` | `reference_date` | DATE |
| `cod_ibge` | `code_muni_6` | VARCHAR |
| `txt_municipio` | `name_muni` | VARCHAR |
| `txt_uf` or `mcmv_fgts_txt_uf` | `state` | VARCHAR |
| `txt_regiao` | `region` | VARCHAR |
| `data_assinatura_financiamento` | `contract_date` | DATE |
| `qtd_uh_financiadas` | `units_financed` | INTEGER |
| `vlr_financiamento` | `amount_financed` | DOUBLE |
| `vlr_subsidio_desconto_fgts` | `subsidy_fgts_discount` | DOUBLE |
| `vlr_subsidio_desconto_ogu` | `subsidy_ogu_discount` | DOUBLE |
| `vlr_subsidio_equilíbrio_fgts` | `subsidy_fgts_interest` | DOUBLE |
| `vlr_subsidio_equilíbrio_ogu` | `subsidy_ogu_interest` | DOUBLE |
| `vlr_compra` | `purchase_price` | DOUBLE |
| `vlr_renda_familiar` | `household_income` | DOUBLE |
| `txt_programa_fgts` | `financing_program` | VARCHAR |
| `num_taxa_juros` | `interest_rate` | DOUBLE |
| `txt_tipo_imovel` | `property_type` | VARCHAR |
| `bln_cotista` | `fgts_account_holder` | VARCHAR |
| `txt_sistema_amortizacao` | `amortization_system` | VARCHAR |
| `dte_nascimento` | `birth_date` | DATE |
| `txt_compatibilidade_faixa_renda` | `income_band` | VARCHAR |
| `txt_nome_empreendimento` | `project_name` | VARCHAR |
| `co_sexo` where published | `sex` | VARCHAR |

Keep a stable 23-column output across the three recognized analytical layouts. Insert typed NULLs for the absent March sex column and for July birth date and project name, and record column availability in provenance. Never infer those fields or fill records from older snapshots. Preserve income-band strings as published: July uses codes rather than the older labels. Document version-specific filters and do not invent a crosswalk for undocumented codes. The input-layout mappings belong in the builder; the registry declares one canonical output schema. The July absence of birth date and project name must not cause a false schema-drift failure for that recognized adapter.

### Official summary

Use an 11-column canonical schema. Map `data_referencia`, `cod_ibge`, `txt_municipio`, `mcmv_fgts_txt_uf`, `txt_regiao`, `num_ano`, `num_mes`, `qtd_uh_financiadas`, `vlr_financiamento`, `vlr_subsidio`, and `txt_compatibilidade_faixa_renda` to `reference_date`, `code_muni_6`, `name_muni`, `state`, `region`, `contract_year`, `contract_month`, `units_financed`, `amount_financed`, `subsidy_total`, and `income_band`. Year and month use INTEGER; band uses VARCHAR.

For the historical eight-column summary, map `txt_uf` and `num_ano_financiamento` to their canonical names and insert typed NULLs for region, month, and income band. Document the annual grain in that snapshot; NULL month means unpublished detail, not January. Preserve missing years. Do not infer a program dimension. For July, document that `subsidy_total` reconciles to all four analytical subsidy components, including interest subsidies; preserve the source total rather than rebuilding it.

### Subsidized projects

Map the 21 fields to `reference_date`, `code_muni_6`, `name_muni`, `state`, `region`, `contract_date`, `operation_code`, `project_name`, `financial_agent`, `modality`, `project_status`, `units_contracted`, `units_delivered`, `units_outstanding`, `units_cancelled`, `amount_contracted`, `amount_disbursed`, `responsible_entity_cnpj`, `responsible_entity_name`, `address`, and `postal_code`.

Keep operation codes, CNPJs, and CEPs as character. Preserve source category variants such as `Rural` and `RURAL`. Retain repeated records and disclose their effect on sums. Do not invent a persistent project identifier.

## Implementation sequence

1. **Freeze source adapters and parsing fixtures.** Recognize the legacy, March, and July analytical layouts; the historical annual and July monthly summaries; and both OGU numeric formats explicitly. Headers alone cannot identify numeric conventions: June OGU retains the old headers but changes locale. Parse all inputs initially as text. Apply Brazilian numeric conversion only to the relevant layouts, including July analytical amounts, June OGU amounts and municipality codes, and the older summary's `110.001` municipality codes and `2.009` years. The July summary uses decimal-point amounts. Declare locale in the source adapter and validate it; never infer it from a single ambiguous number. Use explicit date formats; check that financing timestamps contain no nonmidnight time before converting to dates. Fail on unrecognized layouts or nonempty values that cannot be parsed. Support ZIP and RAR in the build environment, not as user runtime requirements.

2. **Extract narrow shared snapshot helpers.** Reuse the mechanics in `data-raw/cno/build_snapshot.R` for staged output, SQL quoting, Parquet writing, row-count verification, schema hashes, source hashes, and manifest serialization. Put genuinely shared helpers in `data-raw/pipeline/`; leave CNO relational checks and MCMV parsing in their respective builders. Preserve CNO output and schema checksums with regression tests. Avoid designing a general ingestion framework.

3. **Build MCMV snapshots locally.** Add `data-raw/mcmv/build_snapshot.R` and a builder README. Read with DuckDB and write ZSTD Parquet, initially one file per table. Sort financing by state, municipality, and signature date for regional queries. Configure bounded memory and temporary disk spill. Measure output size and representative query performance before deciding whether file partitioning is needed. Every snapshot replaces the full extract; no incremental append.

4. **Register the catalog.** Add `mcmv` with `access_mode: query` to `inst/extdata/datasets.yaml`, including canonical column mappings, definitions, observed coverage, and a schema checksum. Reuse `R/query_dataset.R` without a dataset-specific runtime client. Keep the entry hidden until a validated remote snapshot is available. Use `mcmv-{version}` immutable release tags and a schema-compatible latest pointer such as `mcmv-v1-latest`.

5. **Validate and publish through a dedicated workflow.** Model `.github/workflows/build_mcmv_snapshot.yml` on the CNO workflow, with source URLs, snapshot version, and `publish = false` by default. Store each table's actual reference date separately from retrieval time and snapshot version. Record source URLs, filenames, hashes, layouts, source coverage, row counts, missingness, and known anomalies. Confirm the applicable dataset license instead of copying CNO's license. Upload validated artifacts first; publish immutable assets and update the latest pointer only after success. Start with manual acquisition/publication; add scheduled discovery after current download links and change detection have been tested.

6. **Generate documentation and test access.** Generate dataset documentation from the registry, run `devtools::document()`, and add both a working-with-MCMV article and a dedicated data dictionary article. Register both in `_pkgdown.yml`, cross-link them with the dataset reference page, and add a NEWS bullet. The working article should explain snapshot selection and include examples aggregating financed units and nominal financing amounts before `collect()`.

## Pkgdown data dictionary article

Add `vignettes/articles/mcmv-data-dictionary.Rmd`, titled "MCMV data dictionary", and register `articles/mcmv-data-dictionary` under a "Data dictionaries" article group in `_pkgdown.yml`.

Cover `financing`, `financing_summary`, and `subsidized_projects` separately. State each table's observation grain, reference-date meaning, available identifiers, and limitations on joins and aggregation. For every column, show its normalized name, source header or version-specific aliases, data type, definition, unit, and missing-value conventions. Use the agreed names, including `code_muni_6` and `name_muni`.

Document categorical values and their meanings where supported by the source. Distinguish observed codes from authoritative definitions, particularly for income bands and FGTS account-holder codes. Explain the six-digit IBGE identifier, nominal BRL amounts, source percentage units for interest rates, and the four subsidy components. Describe the July summary's observed subsidy reconciliation without extending it automatically to other releases.

Include a source-version comparison covering annual versus monthly summary grain, changed numeric formats, missing analytical columns, and category changes. Explain absent columns versus missing observations, source duplicates, and incomplete unit-accounting records. Link the Ministry landing page and official dictionary, noting where the dictionary differs from the inspected files.

Generate column names, types, and definitions from the dataset registry where practical so the article and reference documentation share one source of truth. Keep version-specific interpretation alongside those definitions. Build the article without downloading the full datasets or requiring live remote queries.

## Validation and acceptance

Hard failures should cover unexpected headers, archive errors, parsing failures, schema mismatch, and source-to-Parquet row-count changes. Profile missingness, duplicate rows, date ranges, category distributions, negative or extreme values, and unit accounting separately. Preserve documented source anomalies rather than using CNO's unique-key or foreign-key checks for these tables.

Tests should cover both numeric locales (including identical OGU headers with different locales), accented headers, the three analytical layouts, absent sex/birth-date/project-name columns, annual versus monthly summary grain, income-band codes, six-digit codes, unknown categories, blank dates, duplicate preservation, and both matching and nonmatching reference dates. Test lazy filtering and aggregation with local Parquet fixtures through the existing manifest override, explicit version selection, schema rejection, and `close()` behavior. Run existing CNO tests after extracting shared helpers.

Run `pkgdown::check_pkgdown()` and build both MCMV articles. Verify that the dictionary covers every published column, matches the registry, and has working navigation and cross-links.

Before release, run the builder against the complete July analytical and summary inputs and June OGU input. Compare source and Parquet counts and numeric totals with explicit floating-point tolerances. Test a remote filtered query against the published assets before enabling discovery. For analytical and summary files with the same July reference date, reconcile units and financing values by municipality/year/month/income band, and report unmatched groups and value differences explicitly. Require the July fixture to reproduce the observed sum of all four subsidy components within the stated tolerance; report missing component values separately. Do not silently treat missing observations as confirmed zero subsidies. For historical extracts with different reference dates, do not require equality.

Remaining investigations during implementation are authoritative definitions for July income-band and account-holder codes, current online asset identity and acquisition links, coverage differences between historical analytical extracts, and an explanation of repeated OGU records. Verify reference-date parsing and timestamp time components in the builder, and audit analytical duplicate rows before publication without deduplicating them. The design must not depend on source anomalies disappearing.
