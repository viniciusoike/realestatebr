# Municipal IPTU and ITBI from SICONFI: dataset plan

Evidence checked on 23 October 2026. This plan requires maintainer approval before implementation.

## Scope

- Add `get_dataset("siconfi_taxes")`: annual municipal IPTU and ITBI revenue from SICONFI DCA Annex I-C, 2013–2025, in nominal BRL. The [Tesouro DCA metadata](https://www.tesourotransparente.gov.br/ckan/dataset/26fab98f-8cd2-4d34-9176-eef0fb4a296e/resource/1c5351ca-fcb4-4077-9bd9-95bdec8a204d/download/metadadosdca.pdf) defines the unit and annual frequency; [São Paulo 2025](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2025&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) has rows, while the same [2026 query](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2026&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) has none.
- Keep FINBRA before 2013 for a later phase. Do not silently mix its definitions with DCA.
- Publish the tax account shown in Annex I-C, with a marked 2018 comparability break. Do not describe 2013–2025 as one constant-scope tax series.

## Source and verified endpoints

- Base: `https://apidatalake.tesouro.gov.br/ords/siconfi/tt/`. The live [API specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml) names `an_exercicio` and `id_ente` as required for `/dca`; `no_anexo` is optional. The working 2014+ query uses `no_anexo=DCA-Anexo I-C`, for example [São Paulo 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308&limit=10000).
- In 2013, the API returned `Anexo I-C` for [Alta Floresta D'Oeste, RO (1100015)](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=1100015), although its [delivery extract](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/extrato_entregas?id_ente=1100015&an_referencia=2013) says `Balanço Anual (DCA)`. The specification's `DCA-Anexo I-C` prefix rule does not match this live response. Query `Anexo I-C` and verify the 2013 `entregavel` before accepting the rows.
- [São Paulo's 2013 extract](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/extrato_entregas?id_ente=3550308&an_referencia=2013) says `Balanço Anual (QDCC)`; its [2013 `Anexo I-C` rows](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=3550308) must therefore stay out of this DCA dataset.
- [The current `/entes` response](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000) returned 5,598 entities, including 5,570 distinct `esfera=M` municipalities. It is a current register (`exercicio=2026`), not proof that every code existed in every earlier year.
- `/dca` cannot fetch all municipalities for one year: [2024 without `id_ente`](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&limit=10) returned HTTP 200 with zero `items`. Do not read an empty 200 as successful coverage.
- The default page has `limit=5000`; [São Paulo 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) returned 351 rows, `hasMore=false`. With [limit=10 and offset=10](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308&limit=10&offset=10), it returned 10 rows, `hasMore=true`, and a `next` link at offset 20. Follow `hasMore` and increment offset; reject a repeated page.
- The [specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml) caps traffic at one request per second. Sequential sample calls returned HTTP 200 in 0.12–2.21 seconds; no 429 was observed. This small probe cannot establish a higher safe rate. Allow at least one second between starts, plus retry/backoff for transient failures.
- Twelve years × 5,570 municipalities require at least 66,840 `/dca` requests (18.6 hours at the cap). Including 2013 gives 72,410 requests; its extra `/extrato_entregas` lookup adds 5,570, or about 21.7 hours minimum before retries and slow responses. Budget roughly 24–40 hours and make the pipeline resumable. These counts follow from the [municipality register](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000), [endpoint parameters](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml), and observed pagination, not a full harvest.

## Account codes by period

The same IPTU/ITBI pair appeared in each probed year within a period: São Paulo was queried for every year 2014–2025, with boundary checks at [2014](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2014&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), [2017](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2017&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), [2018](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2018&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), [2021](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2021&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), [2022](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2022&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), and [2025](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2025&no_anexo=DCA-Anexo%20I-C&id_ente=3550308). A separate [Alta Floresta D'Oeste 2013 DCA query](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=1100015) checks the first period. These probes do not prove every municipality's code choice.

| Years | IPTU `cod_conta` | ITBI `cod_conta` | Interpretation |
| --- | --- | --- | --- |
| 2013 | `RO1.1.1.2.02.00.00` | `RO1.1.1.2.08.00.00` | [Alta Floresta D'Oeste DCA rows](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=1100015); accept only if its [extract says DCA](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/extrato_entregas?id_ente=1100015&an_referencia=2013). |
| 2014–2017 | `RO1.1.1.2.02.00.00` | `RO1.1.1.2.08.00.00` | Legacy tax lines, checked in [2014](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2014&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2017](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2017&no_anexo=DCA-Anexo%20I-C&id_ente=3550308). |
| 2018–2021 | `RO1.1.1.8.01.1.0` | `RO1.1.1.8.01.4.0` | Revised classification, checked in [2018](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2018&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2021](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2021&no_anexo=DCA-Anexo%20I-C&id_ente=3550308). |
| 2022–2025 | `RO1.1.1.2.50.0.0` | `RO1.1.1.2.53.0.0` | New numbering, checked in [2022](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2022&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2025](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2025&no_anexo=DCA-Anexo%20I-C&id_ente=3550308). |

- [São Paulo 2015](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2015&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2017](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2017&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) also expose separate legacy gross rows for current-tax fines (`RO1.9.1.1.38/39.00.00`), debt-active fines (`RO1.9.1.3.11/12.00.00`), and debt-active principal (`RO1.9.3.1.11/12.00.00`), with IPTU/ITBI alternatives shown by each suffix pair. [2014](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2014&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) exposes only broader debt-active totals, so tax-specific add-ons cannot be recovered consistently for that city-year.
- The [2018 crosswalk](https://www.gov.br/saude/pt-br/acesso-a-informacao/siops/publicacoes/comunicados/2018/comunicado-no-04-2018.pdf) maps those legacy fines/debt lines to `.2`, `.3`, and `.4` child codes under the new tax parents. The [2018](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2018&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) DCA I-C responses expose the `.0` tax parents, not those child rows. The [2024 São Paulo comparison](https://www.saopaulo.sp.leg.br/orcamento2026/wp-content/uploads/sites/68/2025/10/segunda_geral_receita_out_251125.pdf) explicitly says its tax totals include principal, fines, and debt-active receipts.
- Recommend a parent/legacy-line dataset with `account_scope` and a visible 2018 break. Do not add pre-2018 auxiliary rows to the published parent-line value or invent post-2018 principal-only values. A truly constant-scope 2013–2025 series is **not established** by Annex I-C alone; a separately reconciled family-total series could be future work.

## Value choice

- Retain `gross_revenue`, `other_deductions`, and calculated `net_revenue = gross_revenue - other_deductions`. The 2014+ source labels are `Receitas Brutas Realizadas` and `Outras Deduções da Receita`; [2013 DCA](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=1100015) uses `Receitas Realizadas` and `Deduções da Receita`. Treat these as label mappings, not proof of identical tax scope.
- Do not subtract `Deduções - FUNDEB` from IPTU or ITBI. The [MEC's list of Fundeb sources](https://portal.mec.gov.br/component/content/?Itemid=1330&start=100&view=perguntasfrequentes) excludes these own-source taxes. In [São Paulo 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308), that column occurs on transfer accounts, while each tax row has gross and other-deduction values only. Reject unexpected FUNDEB tax rows for review rather than assuming they are valid.
- Missing deduction rows do not prove zero: [Cocos, BA (2908101), 2013 DCA](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2013&no_anexo=Anexo%20I-C&id_ente=2908101) has gross tax rows and no deduction rows. Keep missing deductions and net as `NA` until a documented zero convention is verified. Preserve literal zero values when the API supplies them.
- Net values match independent 2024 reports to their published precision: [São Paulo's budget comparison](https://www.saopaulo.sp.leg.br/orcamento2026/wp-content/uploads/sites/68/2025/10/segunda_geral_receita_out_251125.pdf) gives IPTU R$16,379,899,753 and ITBI R$4,328,007,808 (rounded to reais); the [Rio fiscal targets annex](https://aplicnt.camara.rj.gov.br/APL/Legislativos/scpro.nsf/ab87ae0e15e7dddd0325863200569395/b91a30b1c6124e6f03258cad0040d188/%24FILE/2.%20ANEXO%20DE%20METAS%20FISCAIS.002.pdf/2.%20ANEXO%20DE%20METAS%20FISCAIS.pdf) reports about R$4.906 billion and R$1.433 billion. These are independent checks of 2024 net levels, not checks of every year or tax scope.

The following API values are in BRL; they are prospective regression anchors. Each municipality-year group links its live query.

| Municipality, year | Tax | Gross | Other deductions | Net |
| --- | --- | ---: | ---: | ---: |
| [São Paulo 2017](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2017&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) | IPTU | 8,391,325,245.30 | 127,872,602.67 | 8,263,452,642.63 |
| São Paulo 2017 | ITBI | 1,842,891,549.55 | 2,444,356.68 | 1,840,447,192.87 |
| [Rio de Janeiro 2017](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2017&no_anexo=DCA-Anexo%20I-C&id_ente=3304557) | IPTU | 2,482,263,502.05 | 5,753,178.48 | 2,476,510,323.57 |
| Rio de Janeiro 2017 | ITBI | 655,290,000.06 | 7,424,161.05 | 647,865,839.01 |
| [São Paulo 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) | IPTU | 16,533,492,276.91 | 153,592,524.11 | 16,379,899,752.80 |
| São Paulo 2024 | ITBI | 4,335,013,258.17 | 7,005,450.04 | 4,328,007,808.13 |
| [Rio de Janeiro 2024](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2024&no_anexo=DCA-Anexo%20I-C&id_ente=3304557) | IPTU | 4,946,593,936.34 | 40,587,331.46 | 4,906,006,604.88 |
| Rio de Janeiro 2024 | ITBI | 1,442,603,315.39 | 9,399,149.05 | 1,433,204,166.34 |

## Schema

One row per eligible municipality × year × tax, including municipalities with no DCA I-C. Use the appropriate historical municipality universe before filling absent rows; the [current `/entes` register](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000) alone cannot distinguish later-created municipalities from 2013 non-reporters.

| Column | Type | Description |
| --- | --- | --- |
| `code_muni` | integer | Seven-digit IBGE municipality code, compatible with geobr. |
| `abbrev_state` | character | Two-letter state abbreviation from the entity register. |
| `year` | integer | DCA exercise, 2013–latest closed year. |
| `tax` | character | `iptu` or `itbi`. |
| `reported` | logical | `TRUE` only when the relevant DCA I-C annex is present; 2013 also needs a DCA delivery extract. |
| `value_status` | character | `observed`, `no_dca`, `qdcc_only`, `missing_annex`, or `missing_tax_row`; distinguish missing deductions separately. |
| `gross_revenue` | double | Source gross/realized tax-account value in nominal BRL, else `NA`. |
| `other_deductions` | double | Source non-FUNDEB tax deductions in BRL; `NA` if the row is absent. |
| `net_revenue` | double | Gross minus deductions, rounded to cents when both exist; otherwise `NA`. |
| `account_scope` | character | `legacy_line` through 2017; `tax_family` from 2018. |

## Coverage and missingness

- The [current `/entes` response](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes?limit=10000) supplies 5,570 municipal codes. For each year, report the count of nonempty DCA I-C responses, complete tax pairs, missing tax lines, and missing deduction rows separately. [Campestre, AL, 2025](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2025&no_anexo=DCA-Anexo%20I-C&id_ente=2701357) returned zero I-C rows; its [delivery extract](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/extrato_entregas?id_ente=2701357&an_referencia=2025) has no DCA entry. This supports an explicit `reported=FALSE`, not a zero tax value.
- A live [independent DCA delivery audit](https://prefeiturasemnumeros.com.br/declaracoes) reports 2015–2025 counts, respectively: 5,467; 5,471; 5,559; 5,541; 5,558; 5,561; 5,567; 5,561; 5,557; 5,548; 5,500. These are **DCA found**, not verified Annex I-C/IPTU/ITBI coverage; its own 2025 list identifies two delivered declarations without I-C. The site does not cover 2013–2014. Do not use its counts as a publication gate or label them API counts.
- **Unsettled:** exact usable municipal counts for each year 2013–2025 require the first full per-entity harvest. `/dca` needs `id_ente`, and `/extrato_entregas` also needs `id_ente` and year per the [live specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml). Publish the resulting year-by-year manifest and reconcile differences from the independent audit before releasing a snapshot.
- As of this check, 2025 is the latest closed year with [DCA I-C rows](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2025&no_anexo=DCA-Anexo%20I-C&id_ente=3550308); [2026](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2026&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) had none in the same municipality. “Closed year” does not mean all municipalities reported: the [independent audit](https://prefeiturasemnumeros.com.br/declaracoes) found 70 without a 2025 DCA at its October 2026 check.

## Delivery and caching

- Serve the published `siconfi_taxes.rds` release snapshot by default. `R/cache_github.R` already downloads release assets to a tempfile and memoizes them in-session; `inst/extdata/datasets.yaml` supplies the registry entry. Fresh nationwide collection belongs in the resumable pipeline, not an interactive `get_dataset()` call.
- `R/get_dataset.R` currently tries fresh download when `source="auto"` misses the release cache. Add a registry-backed cache-only policy for this dataset: `auto`/`github` must fail clearly if no verified snapshot exists; an explicit pipeline-only fresh path may rebuild it. A registry entry by itself does **not** prevent the costly fallback.
- Checkpoint each entity-year response outside installed package data; store request URL, retrieval time, response status, checksum, page count, DCA/QDCC evidence for 2013, and parse/validation status. Make retry idempotent and never publish a partial or unexpectedly smaller snapshot. Use the existing `download_with_retry()` in `R/helpers_download.R` with a one-request-per-second scheduler and API-specific HTTP/JSON validation.

## Files to add/change in implementation

- Add `R/get_siconfi_taxes.R` for request parsing, year/code validation, and an explicit fresh builder; add a generated `R/data-siconfi_taxes.R`/help topic from `data-raw/generate_dataset_docs.R`.
- Add `siconfi_taxes` to `inst/extdata/datasets.yaml`; adjust `R/get_dataset.R` for cache-only default and document that behavior.
- Add a resumable `data-raw/siconfi/build_snapshot.R` plus manifest; add validation and publishing targets in `_targets.R` and `data-raw/pipeline/validation.R` (reusing `data-raw/pipeline/targets_helpers.R`).
- Add focused fixtures and `tests/testthat/test-get-siconfi-taxes.R`. Do not add downloaded API payloads or snapshot RDS files to the package source tree.

## Test plan

- Write fixture tests first for 2013 DCA versus QDCC, 2017 legacy codes, 2018 and 2022 recodes, all three deduction labels, absent deduction lines, empty annexes, and pagination (`hasMore`/offset). Include the eight gross/deduction/net anchors above with cent-level tolerance.
- Reject unknown account/column labels, tax-code year mismatches, malformed JSON, non-200 responses, repeated pages, duplicate municipality-year-tax keys, invalid IBGE codes, and a 2013 annex without verified DCA provenance. Preserve reported zeros and NA rows.
- Validate the final manifest against the historical municipality universe and report year-by-year DCA, I-C, gross-tax, and net-value counts. Fail publication on unexplained year loss or schema drift; review differences against the independent delivery audit. Keep live-source tests opt-in, as existing package tests do.

## Risks and open questions

- The 2013 API annex label conflicts with its [own specification](https://apidatalake.tesouro.gov.br/docs/siconfi.yaml); the [delivery extract](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/extrato_entregas?id_ente=1100015&an_referencia=2013) is necessary to avoid mixing DCA and QDCC.
- The 2018 tax-family boundary changes what the parent account includes. The [2015 legacy rows](https://apidatalake.tesouro.gov.br/ords/siconfi/tt/dca?an_exercicio=2015&no_anexo=DCA-Anexo%20I-C&id_ente=3550308) and [2024 São Paulo report](https://www.saopaulo.sp.leg.br/orcamento2026/wp-content/uploads/sites/68/2025/10/segunda_geral_receita_out_251125.pdf) show why one unmarked trend would mislead.
- Confirm the missing-deduction convention and complete annual I-C tax coverage during the full harvest. Until then, do not turn missing rows into zero or assert exact 2013–2025 reporting counts.
