# Municipal IPTU and ITBI from SICONFI: dataset plan

Evidence checked on 23 October 2026. Revised on 23 October 2026 to a hybrid
design: FINBRA bulk CSVs for history, SICONFI API only to refresh the latest
two years. This plan requires maintainer approval before implementation.

## Scope

- Add `get_dataset("siconfi_taxes")`: annual municipal IPTU and ITBI revenue
  from SICONFI DCA Annex I-C, 2013–2025, in nominal BRL. The
  [Tesouro DCA metadata](https://www.tesourotransparente.gov.br/ckan/dataset/26fab98f-8cd2-4d34-9176-eef0fb4a296e/resource/1c5351ca-fcb4-4077-9bd9-95bdec8a204d/download/metadadosdca.pdf)
  defines the unit and annual frequency.
- History comes from FINBRA bulk files (`MUN Receitas Orçamentárias, Anexo
  I-C`), downloaded once by the maintainer. Updates re-fetch the latest two
  years from the SICONFI API and replace FINBRA rows for those years. The
  `source` column records which source produced each row (`finbra` or `api`;
  `NA` for non-reporters).
- Municipalities that filed QDCC instead of DCA in 2013 (São Paulo included)
  are accepted **as published in FINBRA 2013**. The API-only plan's
  per-municipality DCA/QDCC 2013 provenance check is dropped; the caveat goes
  in the plan and the dataset help.
- **Decided (D2):** the Distrito Federal (5300108) is dropped from the
  municipality universe. It reports IPTU and ITBI in its state-level
  accounts, so it never appears in the municipal files (`/entes` lists 5,570
  `esfera = M` entries; 5,569 after the exclusion). The pipeline asserts
  that every other universe municipality appears in at least one FINBRA
  year and aborts listing the codes otherwise.
- Publish the tax account shown in Annex I-C with a marked 2018 comparability
  break (`account_scope`). Do not describe 2013–2025 as one constant-scope tax
  series and do not build a reconstructed constant-scope series.
- FINBRA pre-2013 (`MUN Receitas Anexo I-a, I-b`) stays out of scope.

## Source and verified endpoints

### FINBRA bulk files (history, primary)

- 13 ZIPs at `data-raw/siconfi/finbra/` **outside the repository and
  gitignored** (`data-raw/siconfi/finbra/` never enters git); file names are
  not informative, so the builder reads the year from the CSV. Each ZIP holds
  one `finbra.csv`; the 13 files map one-to-one to exercises 2013–2025
  (verified from the `Exercício:` header of each).
- Format, verified on 2013, 2017, 2022 and 2024 and seen around drifts on
  2015–2020:
  - Encoding Windows-1252 (latin1). Lines 1–3 are metadata: `Exercício:
    <year>`, `Escopo: Municípios`, `Tabela: Receitas Orçamentárias (Anexo
    I-C)`. Line 4 is the header:
    `Instituição;Cod.IBGE;UF;População;Coluna;Conta;Identificador da Conta;Valor`.
  - Delimiter `;`, decimal comma, no thousands separator (e.g.
    `16533492276,91`). Quoted fields keep their quotes on a naive split.
  - Quoting is broken: the `Conta` name may contain unescaped `"`, e.g.
    `... Transmissão "Inter Vivos" de Bens Imóveis ...`. Never parse these
    files with a standard CSV reader; identify tax rows by the 7th field (from
    the end: `Valor`, then `Identificador da Conta`) and verify tax rows keep
    exactly 8 fields.
  - Verified and safe for tax rows: every line whose `Identificador da Conta`
    is one of the six tax codes below split into exactly 8 fields in all
    probed years. Account names in some non-tax rows contain `;` (~24 rows in
    2015) and even embedded newlines (~14k physical continuation lines in 2019
    and 2020, always SUS/consortium transfer accounts); the 8-field rule keeps
    tax rows out of that corruption class.
  - Column-label vintages: 2013 uses `Receitas Realizadas` and `Deduções da
    Receita`; 2014+ uses `Receitas Brutas Realizadas` and `Outras Deduções da
    Receita`. `Deduções - FUNDEB` and `Deduções - Transferências
    Constitucionais` never feed tax deductions. 2013 account names contain a
    `¿` mojibake character in the source; account names are ignored.
- Municipalities per year (distinct 7-digit `Cod.IBGE` in each file, counted
  from the bulk extracts; non-reporters are municipalities absent from the
  file):

  | Year | 2013 | 2014 | 2015 | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | Municipalities | 5,481 | 5,191 | 5,440 | 5,442 | 5,556 | 5,536 | 5,553 | 5,559 | 5,562 | 5,557 | 5,557 | 5,546 | 5,502 |

- **Known caveat:** the 2014 file covers only 5,191 municipalities, about 250
  fewer than 2013 and 2015. This may be real non-reporting or an incomplete
  bulk export; treat the 2014 count conservatively and revisit against
  Tesouro's own delivery notes before publishing a coverage claim.
- Right after publication, each bulk file includes amendments up to its
  download date; the API refresh below supersedes the two latest years.

### SICONFI API (updates, latest two years)

- Base: `https://apidatalake.tesouro.gov.br/ords/siconfi/tt/`. The
  [specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml) names
  `an_exercicio` and `id_ente` as required for `/dca`; `no_anexo` is optional.
  The working query uses `no_anexo=DCA-Anexo I-C`, for example
  [São Paulo 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308&limit=10000).
- `/dca` cannot fetch a whole year in one request:
  [2024 without `id_ente`](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&limit=10)
  returns HTTP 200 with zero `items`. Do not read an empty 200 as coverage.
- Pagination (verified again on 23 Oct 2026 with `limit=2`): responses carry
  `hasMore`, `limit`, `offset`, `count`; follow `hasMore` by advancing `offset`
  by the returned `limit` and reject a repeated page. Item fields are
  `exercicio, instituicao, cod_ibge, uf, anexo, rotulo, coluna, cod_conta,
  conta, valor, populacao`; `coluna` uses the 2014+ labels above.
- The [specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml)
  caps traffic at one request per second. Allow at least one second between
  starts plus retry/backoff for transient failures.
- **Refresh policy (decided):** each update re-fetches the latest two closed
  years for every municipality and replaces the FINBRA rows for those years
  (one request per municipality-year; 2 × 5,500 ≈ 11k requests, ≈ 3.1 hours at
  the cap). Replace the whole municipality-year tax rows, not single fields,
  so `source` is unambiguous per row. Municipalities that never file keep
  their `reported = FALSE` rows from the FINBRA pass with `source = NA`.
- The [current `/entes` response](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000)
  lists 5,570 distinct `esfera=M` municipalities, minus the Distrito
  Federal (5300108, see the D2 scope decision) giving a 5,569-municipality
  universe. It is a current register,
  not proof that every code existed in every earlier year; the non-reporter
  fill uses the per-year IBGE municipality universe (geobr-compatible codes),
  not `/entes` alone.

## Account codes by period

Verified against the FINBRA files for São Paulo (3550308) and Rio de Janeiro
(3304557) in 2013, 2017, 2018, 2022 and 2024; the same pair appeared in API
probes for every year 2014–2025. The municipality-year context accounts
(Receitas Correntes and Impostos, Taxas e Contribuições de Melhoria) were
verified against every FINBRA file 2013–2025 and the live API for 2017 and
2025 on 24 October 2026 (São Paulo's values printed per year):

| Years | IPTU identifier | ITBI identifier | current_revenue identifier | tax_revenue identifier | `account_scope` |
| --- | --- | --- | --- | --- | --- |
| 2013–2017 | `siconfi-cor_RO1.1.1.2.02.00.00` | `siconfi-cor_RO1.1.1.2.08.00.00` | `siconfi-cor_RO1.0.0.0.00.00.00` | `siconfi-cor_RO1.1.0.0.00.00.00` | `legacy_line` |
| 2018–2021 | `siconfi-cor_RO1.1.1.8.01.1.0` | `siconfi-cor_RO1.1.1.8.01.4.0` | `siconfi-cor_RO1.0.0.0.00.0.0` | `siconfi-cor_RO1.1.0.0.00.0.0` | `tax_family` |
| 2022–2025 | `siconfi-cor_RO1.1.1.2.50.0.0` | `siconfi-cor_RO1.1.1.2.53.0.0` | `siconfi-cor_RO1.0.0.0.00.0.0` | `siconfi-cor_RO1.1.0.0.00.0.0` | `tax_family` |

São Paulo anchors read from the files (gross realized, `Receitas
Realizadas` 2013 / `Receitas Brutas Realizadas` 2014+; population as
published):

| Year | population | current_revenue | tax_revenue |
| --- | ---: | ---: | ---: |
| 2013 | 11,821,873 | 37,710,663,491.90 | 18,565,985,119.76 |
| 2017 | 12,038,175 | 50,970,741,521.99 | 25,715,190,301.72 |
| 2018 | 12,038,175 | 52,983,577,439.67 | 30,083,861,181.61 |
| 2022 | 12,396,372 | 84,950,618,664.24 | 48,012,216,722.71 |
| 2024 | 12,200,180 | 101,553,334,044.89 | 62,707,212,200.14 |
| 2025 | 12,200,180 | 108,153,374,942.34 | 68,282,433,803.83 |

The 2024 API response and the 2025 API response (São Paulo and
Quilombo-SC) match the FINBRA figures above exactly, for the tax totals
and the `populacao` field alike — but the API `populacao` is never used:
population is a FINBRA-only figure by decision.

## Municipality-year context (approved 24 October 2026)

- Three context columns ride along on both tax rows, placed after `year`
  and before `tax`: `population` (integer), `current_revenue` and
  `tax_revenue` (double, nominal BRL), enabling per-capita values and
  IPTU's share of own revenue.
- **Population** comes only from the FINBRA `População` field of the same
  year; never from IBGE or the API. Verified constant across all lines of
  a municipality-year in all 13 bulk files; a conflicting value aborts
  with `cli`. For API years without a FINBRA file of that year (none
  today), `population` is NA.
- **`current_revenue` = Receitas Correntes** (`RO1.0.0.0.00.0.0` in
  2018+; `RO1.0.0.0.00.00.00` 2013–2017) and **`tax_revenue` = Impostos,
  Taxas e Contribuições de Melhoria** (`RO1.1.0.0.00.0.0` in 2018+;
  `RO1.1.0.0.00.00.00`, "Receita Tributária", 2013–2017). Both are gross
  realized values (the `Receitas Realizadas`/`Receitas Brutas Realizadas`
  column, as `gross_revenue`); FUNDEB and transfer columns never feed
  them. For API-supplied years the totals come from the API items (same
  vintage codes and column labels), so a municipality-year's context
  stays from one source; population keeps the FINBRA figure. A reporting
  municipality without the account line keeps NA (never zero);
  non-reporters get NA for all three.

- Rows sharing the legacy codes' family (fines and old-debts under
  `RO1.9.1.1.38/39` and `RO1.9.1.3.11/12` in 2015–2017, and `.2/.3/.4` child
  codes under the 2018 parents) are **excluded** from the published tax
  values: the pre-2018 tax line alone is not comparable to the post-2018 tax
  family, and that break is exactly what `account_scope` marks.
- Who is not comparable with whom: the 2018
  [crosswalk](https://www.gov.br/saude/pt-br/acesso-a-informacao/siops/publicacoes/comunicados/2018/comunicado-no-04-2018.pdf)
  maps legacy fines/debt lines into the new parents; the [2024 São
  Paulo budget comparison](https://www.saopaulo.sp.leg.br/orcamento2026/wp-content/uploads/sites/68/2025/10/segunda_geral_receita_out_251125.pdf)
  states the tax totals include principal, fines, and debt-active receipts.

## Value choice

- Retain `gross_revenue`, `other_deductions`, and calculated
  `net_revenue = gross_revenue - other_deductions` (rounded to cents);
  tolerate cent-level rounding relative to the anchors. **Decided (D1):** a
  municipality-year-tax with an observed gross row but no deduction row
  counts the deduction as zero: `other_deductions = 0`, `net_revenue` is
  computed, and the new logical column `deductions_reported` marks the
  assumption (`FALSE`, right after `other_deductions`; `TRUE` when a
  deduction row existed; `NA` when there is no gross row). Keys with a
  deduction row but no gross row keep `gross_revenue` and `net_revenue`
  `NA`. Literal zero deduction values are preserved (verified: a 2015 São
  Bernardo do Campo zero `Outras Deduções da Receita` tax row; Quilombo
  2022 zero rows).
- Do not subtract `Deduções - FUNDEB` from IPTU or ITBI; the
  [MEC Fundeb list](https://portal.mec.gov.br/component/content/?Itemid=1330&start=100&view=perguntasfrequentes)
  excludes these own-source taxes. Verified in the bulk files: the FUNDEB and
  Transferências columns appear on tax-identifier rows only outside the tax
  value columns (e.g. Quilombo, SC, 2022 carries literal-zero FUNDEB/
  Transferências rows for IPTU/ITBI identifiers).
- Missing-deduction share context: an ~8k-per-year share of
  municipality-tax combinations in each bulk file has a gross row without a
  deduction row; per the D1 decision these are zero-deduction rows with
  `deductions_reported = FALSE`.

### Regression anchors — verified against FINBRA bulk files on 23 Oct 2026

All eight anchors match the FINBRA values **exactly** (gross and deductions to
the cent). São Paulo 2024 FINBRA also equals the API response with no
difference. These values are the fixture and validation anchors.

| Municipality, year | Tax | Gross | Other deductions | Net |
| --- | --- | ---: | ---: | ---: |
| São Paulo 2017 | IPTU | 8,391,325,245.30 | 127,872,602.67 | 8,263,452,642.63 |
| São Paulo 2017 | ITBI | 1,842,891,549.55 | 2,444,356.68 | 1,840,447,192.87 |
| Rio de Janeiro 2017 | IPTU | 2,482,263,502.05 | 5,753,178.48 | 2,476,510,323.57 |
| Rio de Janeiro 2017 | ITBI | 655,290,000.06 | 7,424,161.05 | 647,865,839.01 |
| São Paulo 2024 | IPTU | 16,533,492,276.91 | 153,592,524.11 | 16,379,899,752.80 |
| São Paulo 2024 | ITBI | 4,335,013,258.17 | 7,005,450.04 | 4,328,007,808.13 |
| Rio de Janeiro 2024 | IPTU | 4,946,593,936.34 | 40,587,331.46 | 4,906,006,604.88 |
| Rio de Janeiro 2024 | ITBI | 1,442,603,315.39 | 9,399,149.05 | 1,433,204,166.34 |

The original plan's API anchors for 2017 come from the live API and match the
FINBRA values above for São Paulo and (via FINBRA) Rio de Janeiro as well.

## Schema

One row per municipality × year × tax, including municipalities absent from
the year's bulk file (reported but with withheld/absent data are flagged,
not zero-filled).

| Column | Type | Description |
| --- | --- | --- |
| `code_muni` | integer | Seven-digit IBGE municipality code, geobr-compatible. |
| `abbrev_state` | character | Two-letter state abbreviation from the source row. |
| `year` | integer | Exercise year, 2013–latest closed year. |
| `population` | integer | Population figure carried on the FINBRA file's lines for that municipality-year (`População`), repeated on both tax rows; NA for API years without a FINBRA file and for non-reporters. |
| `current_revenue` | double | Gross realized total current revenue (Receitas Correntes) of the municipality-year in nominal BRL; repeated on both tax rows. NA when absent or non-reporter. |
| `tax_revenue` | double | Gross realized Impostos, Taxas e Contribuições de Melhoria of the municipality-year in nominal BRL; repeated on both tax rows. NA when absent or non-reporter. |
| `tax` | character | `iptu` or `itbi`. |
| `reported` | logical | `TRUE` when the municipality appears in that year's FINBRA file (or the refreshed API rows). |
| `value_status` | character | `observed` (tax row present), `missing_tax_row` (municipality filed but that tax has no gross row), or `non_reporter` (absent from the file). |
| `gross_revenue` | double | Realized gross tax-account value in nominal BRL, else `NA`. |
| `other_deductions` | double | Non-FUNDEB tax deductions in BRL; an observed-gross key with no deduction row publishes 0, else the observed value (NA with no gross row). |
| `deductions_reported` | logical | `TRUE` when the source carried a deduction row; `FALSE` when the 0 in `other_deductions` was assumed; `NA` when there is no gross row. |
| `net_revenue` | double | Gross minus deductions, computed whenever the gross row exists, else `NA`. |
| `account_scope` | character | `legacy_line` through 2017; `tax_family` from 2018. |
| `source` | character | `finbra` or `api`; `NA` for non-reporter rows. |

## Delivery and caching

- Serve the published `siconfi_taxes.rds` release snapshot by default. The
  registry (`inst/extdata/datasets.yaml`) gets a `siconfi_taxes` entry with a
  `cached_file`; `get_dataset(source = "github")` reads it through the
  existing `fetch_github_release_asset()` path.
- **`source = "fresh"` must abort with a clear `cli` error** for this dataset:
  a fresh rebuild requires the maintainer's local FINBRA files (never in the
  repo) and hours of API calls; it belongs in `data-raw/siconfi/
  build_snapshot.R`, not in an interactive call.
- **`source = "auto"` must not silently fall back to a fresh download** for
  this dataset. `R/get_dataset.R` gets a registry-backed cache-only policy:
  `auto`/`github` fail clearly when no verified snapshot exists, and no
  `dataset_function` fresh path is registered for this dataset.
- `build_snapshot.R` reads the 13 local ZIPs (paths supplied by the user),
  optionally reparses nothing outside the package, then calls the API for the
  latest two years with checkpoints, 1 req/s pacing, and retries; the builder
  then replaces FINBRA rows for those years, validates, and writes the
  release-ready RDS plus manifest (schema hash, per-year coverage counts,
  FINBRA file checksums, refresh timestamps). Never publish a partial or
  unexpectedly smaller snapshot; the per-year municipality counts above are
  the sanity gate.

## Files to add/change in implementation

- Add `R/get_siconfi_taxes.R` with `read_finbra_file()`, `parse_siconfi_dca()`,
  `fetch_siconfi_dca()`, `build_siconfi_taxes()`, and
  `validate_siconfi_taxes()` as the unit-tested core.
- Add the `siconfi_taxes` registry entry in `inst/extdata/datasets.yaml` and
  the cache-only policy in `R/get_dataset.R`; add a generated help topic from
  `data-raw/generate_dataset_docs.R`.
- Add `data-raw/siconfi/build_snapshot.R` plus manifest; `data-raw/siconfi/
  finbra/` stays gitignored and outside version control.
- Add fixtures and `tests/testthat/test-get-siconfi-taxes.R`. Fixtures only,
  a few KB each: real FINBRA excerpts (2013, 2017, 2018, 2022, 2024) in the
  original latin1 format, one small zipped copy, trimmed real API responses.
  Do not add downloaded bulk files, API payloads, or snapshot RDS files to the
  package source tree.

## Test plan

Fixture-based, TDD; failing tests land before the functions (this phase).

- `read_finbra_file()`: year from the header (a differently-named zipped
  copy must yield the embedded year), both column-label vintages, the three
  code periods mapped to `tax`, `account_scope` boundaries, the unescaped
  `Inter Vivos` quote line, latin1 handling, gross/deduction kinds, literal
  zeros, and the eight anchors with cent tolerance. `cli` errors: bad/absent
  `Exercício` header, unknown column label on a tax row, unknown tax code for
  the file year, malformed numbers.
- `parse_siconfi_dca()`: real trimmed `/dca` items to the same long form;
  unknown `cod_conta` for the year, unknown `coluna`, and malformed values
  abort.
- `fetch_siconfi_dca()`: pagination follows `hasMore` across two real
  trimmed pages and rejects a repeated page; `request` is injectable so tests
  stay offline.
- `build_siconfi_taxes()`: API rows replace FINBRA rows for the same year and
  set `source = "api"`; net computed with cent tolerance; non-reporters filled
  from the given municipality universe with `reported = FALSE` and `NA`
  values; missing deduction keeps `gross`, nets `NA`.
- `validate_siconfi_taxes()`: unique `code_muni` × `year` × `tax`, 7-digit
  `code_muni` integers, schema check, `cli::cli_abort()` on failure including
  duplicate keys.
- Interface: the registry entry exists; `get_dataset("siconfi_taxes",
  source = "fresh")` aborts; `source = "auto"` does not silently download
  anything; `source = "github"` reads the release asset with
  `fetch_github_release_asset` mocked.
- Live tests stay opt-in (`REALESTATEBR_RUN_LIVE`) like other datasets.

## Risks and open questions

- **2014 bulk count (5,191)** is suspiciously low against neighbors
  (5,481/5,440); reconcile against Tesouro delivery notes before any coverage
  statement for that year.
- The `Conta` corruption class (`;` and embedded newlines in quoted names)
  affects transfer accounts in 2015–2020. The parse rule above (identifying
  tax rows by their 7th field, validating 8 fields) keeps tax rows safe in
  all files probed; any future layout change must fail loudly, never silently
  drop.
- Unescaped quotes inside quoted `Conta` names mean standard CSV readers
  misparse the files; document the hand-rolled reader as the only supported
  FINBRA path.
- The refresh window "latest two years" assumes the bulk files are
  re-downloaded when they start including a new year; when Tesouro publishes,
  e.g., the 2026 exercise as the newest bulk file, the API refresh must move
  to 2025–2026. Keep the refresh years a parameter of `build_snapshot.R`,
  not a constant in the dataset function.
- Municipalities created after 2012 must not be classified as 2013
  non-reporters; the fill needs the per-year IBGE historical universe.
- Missing-deduction convention: resolved by decision D1 (assume zero with
  `deductions_reported` recording the assumption).
- FINBRA 2013 mixes DCA and QDCC filings; documented caveat in the help, not
  a data flag (decided).
