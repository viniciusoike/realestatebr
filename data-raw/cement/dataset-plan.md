# SNIC monthly cement dataset: source audit and implementation plan

## Scope

- **Finding (checked 2026-10-23):** The two current SNIC regional series support monthly apparent consumption and production by state, but the archived state series has a 34-month gap from 2014-03 through 2016-12. Do not promise uninterrupted state coverage until that gap has a source. [A03], [A04], [SNIC index](https://snic.org.br/numeros-da-industria.php).
- Publish `get_dataset("cement", table = "consumption")` as the headline table and `table = "production"` as the companion. Use `consumption` as the default table; production has structural missing states. [A03], [A04], [SNIC production 2025](https://snic.org.br/assets/pdf/numeros/1784570386.pdf).
- Keep one long table per concept, including state, regional adjustment, region total, and Brazil total rows. A geography type prevents double counting; never allocate `Ajustes` to states. [SNIC consumption 2024](https://snic.org.br/assets/pdf/numeros/1752521135.pdf).
- The producer and public attribution are SNIC. The archived workbooks are historical inputs, not evidence that their distributor produced the series. [A03], [A04], [prior decision](/Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/README.md).

## Sources and verified links

- [SNIC index](https://snic.org.br/numeros-da-industria.php) currently has 22 opaque-timestamp PDFs. Resolve an exact Portuguese link label such as `Consumo Regional 2026`, then join its relative `href` to the index URL; reject missing or duplicate labels and non-SNIC PDF URLs. Never hard-code the timestamp.
- Consumption by state: [2024](https://snic.org.br/assets/pdf/numeros/1752521135.pdf) (January–December), [2025](https://snic.org.br/assets/pdf/numeros/1784570419.pdf) (January–December), [2026](https://snic.org.br/assets/pdf/numeros/1792582081.pdf) (January–March at this check).
- Production by state: [2024](https://snic.org.br/assets/pdf/numeros/1752521165.pdf) (January–December), [2025](https://snic.org.br/assets/pdf/numeros/1784570386.pdf) (January–December), [2026](https://snic.org.br/assets/pdf/numeros/1792582103.pdf) (January–March at this check).
- The index also links national monthly [consumption](https://snic.org.br/assets/pdf/numeros/1792582071.pdf) and [production](https://snic.org.br/assets/pdf/numeros/1792582044.pdf) for 2019–2026. They can check Brazil totals but cannot fill state gaps.
- Every regional PDF above carries `(*) Dados preliminares sujeitos à revisão`; the index has no separate final regional PDF. [SNIC index](https://snic.org.br/numeros-da-industria.php), [2026 consumption PDF](https://snic.org.br/assets/pdf/numeros/1792582081.pdf).
- The separate [preliminary-results index](https://snic.org.br/numeros-resultados-preliminares.php) lists monthly releases through September 2026, but the state PDFs stop at March 2026. The site gives no reliable state-PDF release schedule; update when a newly linked regional PDF adds months, not on an assumed monthly cadence.
- The site footer says “© 2026 SNIC - Sindicato Nacional da Indústria do Cimento.” The index and six regional PDFs contain no explicit reuse licence or republication terms; this copyright notice does not grant redistribution rights. [SNIC index](https://snic.org.br/numeros-da-industria.php), [2026 production PDF](https://snic.org.br/assets/pdf/numeros/1792582103.pdf).
- Direct `curl` and `httr::GET()` on this machine failed certificate validation (`unable to get local issuer certificate`). The original probe used certificate bypass only to inspect six PDFs. A later `openssl s_client -connect snic.org.br:443 -servername snic.org.br -showcerts` check on 2026-10-23 found that the server sends its Let's Encrypt YR1 intermediate, but its leaf certificate expired on 2026-09-03. A pinned CA bundle cannot cure an expired leaf. The pipeline must fail with a clear `cli` error naming the expired certificate; PDF refresh stays blocked until SNIC renews it. Keep TLS verification on, without a bypass in package or pipeline code. The maintainer will notify SNIC alongside the permission request. [SNIC index](https://snic.org.br/numeros-da-industria.php).

## Extraction approach

- Use `pdftools::pdf_text()` behind `requireNamespace("pdftools", quietly = TRUE)`; add `pdftools` to Suggests. All six one-page PDFs retain aligned headers, row labels, 12 month columns, and a total. After removing `pdftotext`'s trailing form feed, its `-layout` text matched `pdftools` output in the probe. [six PDF links above](https://snic.org.br/numeros-da-industria.php).
- Parse a regional PDF's concept and year from its title, then require one `Jan`–`Dez` header and exactly 27 named state rows, five region totals, four `Ajustes` rows, and one Brazil total. Production has 23 states with numeric values and four states shown as `-` in 2024–2026; retain these as missing, not zero. [2025 production PDF](https://snic.org.br/assets/pdf/numeros/1784570386.pdf).
- Split data lines at runs of at least two spaces, parse periods as thousands separators, and map state names through an explicit 27-state dictionary. Map each `Ajustes` to its region by section, reject unknown or duplicate rows, and treat `-` as unavailable.
- Call `cli::cli_abort()` on changed titles, month headers, row counts, unrecognized tokens, duplicate keys, totals that do not equal the sum of available months, or non-reconciling regional/Brazil totals. The six checked PDFs reconcile exactly, including adjustments. [2024–2026 regional PDFs](https://snic.org.br/numeros-da-industria.php).
- Define apparent consumption in tonnes using SNIC's footnote: “Inclui estimativa do cimento despachado no país por misturadores e fábricas integradas não associadas e importação”. Production excludes the import clause and says “cimento produzido no país”. [2026 consumption](https://snic.org.br/assets/pdf/numeros/1792582081.pdf), [2026 production](https://snic.org.br/assets/pdf/numeros/1792582103.pdf).

## Archive structure

- [A03] and [A04] each have 23 year-named sheets, 2003–2025. Row 1 holds the title, row 2 the year and provisional status, row 3 says `em toneladas`, row 5 holds `JAN`–`DEZ` in columns B–M, and column N holds annual or year-to-date totals. Each sheet ends with source and missing-data footnotes. [A03], [A04].
- State labels are in column A; region subtotals follow each region's states, and `TOTAL BRASIL` closes the data. `Ajustes` starts in 2004 and appears in up to four regions; the Centro-Oeste region has no adjustment row in the checked recent sheets. [A03], [A04].
- Read sheets with `readxl`, verify title/month/unit/row labels per sheet, and pivot B–M to first-of-month `date`. Keep numeric tonnes as double: A03 contains fractional values in 2004–2006. Treat `...`, `....`, blank, and absent future months as missing. Do not turn formula-cache zeroes into observations. [A03], [A04].
- A03's 2025 sheet contains January only; A04's 2025 sheet does too. Both have complete regional and Brazil totals for 2014–2016, but all state entries are missing from 2014-03 through 2016-12. This is 918 missing state-month cells for consumption. The older editions repeat this gap. [A03], [A04], [A03-old], [A04-old].
- The companion [A01] is annual consumption by geography from 1980; [A02] is one national annual table through 2023. Neither recovers missing monthly state observations. The [SNIC annual-report index](https://snic.org.br/numeros-relatorio-anual.php) lists 2013 then 2019, with no 2014–2018 annual report link. [A01], [A02].
- The checked input identities are A03 SHA-256 `1204150b8e4c75a3e9c9a01b24f5bfde555383ecda456c199e970263387f6c9d`; A04 SHA-256 `67057ddc8d9f54130d71289035f1110b8dc37753eebc9cd4af6eeccef8ed72d6`. [A03], [A04].

## Overlap check results

The probe compared every available 2024–2025 month by state, regional adjustment, region total, and Brazil total, using the six linked PDFs and the two archive files. A match means equal tonnes, not merely equal annual sums. [A03], [A04], [SNIC index](https://snic.org.br/numeros-da-industria.php).

| Concept and year | State cells compared | Other cells compared | Differing cells | PDF-only later-month cells |
| --- | ---: | ---: | ---: | ---: |
| Consumption 2024 | 324/324 | 120/120 | 0 | 0 |
| Production 2024 | 276/276 numeric | 120/120 | 0 | 0 |
| Consumption 2025 | 27/27 January | 10/10 January | 0 | 407 |
| Production 2025 | 23/23 January | 10/10 January | 5 | 363 |

- Production January 2025 changed in the current PDF: Ceará `272,197 → 264,206` (−7,991 t); Sergipe `178,283 → 175,813` (−2,470 t); Bahia `101,452 → 103,922` (+2,470 t). Nordeste `1,168,618 → 1,160,627` and Brazil `4,944,931 → 4,936,940` (both −7,991 t). The four `Ajustes` entries did not change. [A04], [SNIC production 2025](https://snic.org.br/assets/pdf/numeros/1784570386.pdf).
- All 2024 PDF monthly region totals equal state values plus adjustments, and the five region totals equal Brazil; the same holds for 2025 and the three published 2026 months. The archive's region totals equal Brazil throughout, but missing state values prevent a state-level check for the 2014–2016 gap. [A03], [A04], [six regional PDFs](https://snic.org.br/numeros-da-industria.php).
- This comparison proves at least one revision between the archived January 2025 production vintage and today's PDF. It cannot measure every intra-year revision because SNIC does not expose earlier PDF vintages on the current index. [A04], [SNIC index](https://snic.org.br/numeros-da-industria.php).

## Comparability across the gap

The table compares each state's and region's share of the Brazil consumption total in the two complete years before the monthly state gap (2012–2013) with the two complete years after it (2017–2018). Each share divides the two-year sum by the corresponding two-year Brazil sum; regional totals include their `Ajustes` rows. Values are percentage points of Brazil consumption, rounded to two decimals. [A03].

| Geography | 2012–2013 | 2017–2018 | Change |
| --- | ---: | ---: | ---: |
| Rondônia | 1.25 | 0.73 | −0.52 |
| Acre | 0.26 | 0.28 | +0.02 |
| Amazonas | 1.45 | 0.97 | −0.48 |
| Roraima | 0.16 | 0.17 | +0.01 |
| Pará | 3.11 | 2.76 | −0.35 |
| Amapá | 0.36 | 0.24 | −0.12 |
| Tocantins | 0.74 | 0.84 | +0.10 |
| **North** | **7.33** | **6.38** | **−0.95** |
| Maranhão | 2.20 | 1.61 | −0.59 |
| Piauí | 1.05 | 1.37 | +0.32 |
| Ceará | 2.83 | 3.56 | +0.73 |
| Rio Grande do Norte | 1.37 | 1.06 | −0.30 |
| Paraíba | 1.66 | 1.40 | −0.26 |
| Pernambuco | 4.07 | 3.24 | −0.83 |
| Alagoas | 1.17 | 0.66 | −0.51 |
| Sergipe | 0.88 | 0.79 | −0.09 |
| Bahia | 5.47 | 5.68 | +0.20 |
| **Northeast** | **21.36** | **22.64** | **+1.28** |
| Minas Gerais | 10.24 | 9.76 | −0.48 |
| Espírito Santo | 1.95 | 2.10 | +0.16 |
| Rio de Janeiro | 6.84 | 4.38 | −2.46 |
| São Paulo | 21.56 | 18.68 | −2.88 |
| **Southeast** | **44.89** | **43.90** | **−0.99** |
| Paraná | 6.49 | 7.07 | +0.58 |
| Santa Catarina | 4.80 | 5.50 | +0.70 |
| Rio Grande do Sul | 4.99 | 5.03 | +0.05 |
| **South** | **16.66** | **17.71** | **+1.06** |
| Mato Grosso do Sul | 1.45 | 1.63 | +0.18 |
| Mato Grosso | 2.14 | 2.38 | +0.24 |
| Goiás | 4.45 | 4.27 | −0.18 |
| Distrito Federal | 1.72 | 1.08 | −0.64 |
| **Center-West** | **9.76** | **9.36** | **−0.40** |

The sum of `Ajustes` rises from 5.34% to 12.73% of Brazil consumption. The archive footnotes call unavailable monthly state values `...` and warn that reported values may be revised; they do not describe a switch in state attribution. SNIC's [2013 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2013.pdf) and [2019 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2019.pdf) retain the same annual apparent-consumption concept, and the 2019 report says estimates for non-member producers were also included in earlier reports. SNIC's [2012 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2012.pdf) explicitly documents that practice before the gap. The annual reports give 2014–2016 state totals, including São Paulo's gradual decline from 15.089 million tonnes in 2013 to 15.017, 13.140, and 10.982 million tonnes in 2014–2016, but no monthly state observations to fill the archive gap. [A03], [2019 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2019.pdf).

**Conclusion:** The checked notes do not establish an origin-to-destination redefinition or a dated methodology break. The much larger unattributed estimate share makes state levels and shares across the monthly gap less comparable, even if part of the change reflects the market downturn. Preserve the published values and `Ajustes` separately, do not rescale states, and explain this uncertainty in the dataset help. [A03], [2019 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2019.pdf).

## Splice rule

- Use A03/A04 for available months through 2023-12; use current SNIC PDFs for every month from 2024-01. The full 2024 agreement supports this boundary, and the January 2025 production differences favor the current producer PDF. [A03], [A04], [2024 production](https://snic.org.br/assets/pdf/numeros/1752521165.pdf), [2025 production](https://snic.org.br/assets/pdf/numeros/1784570386.pdf).
- On every refresh, re-read all linked regional years and replace the PDF-covered period atomically. Do not append only the newest month: preliminary values can change. Save source URL, retrieval date, file hash, and overlap diff in the pipeline log.
- Leave 2014-03–2016-12 state rows missing. Keep available region/Brazil totals, but never infer state values from them or from A01 annual figures. Gate any claim of continuous state coverage on finding a verified monthly state source. [A03], [A04], [A01].

## Schema

Both `consumption` and `production` use the same fields; a `(date, geography_type, code_region, code_state)` key is unique when missing codes are compared as explicit geography types.

| Column | Type | Description |
| --- | --- | --- |
| `date` | Date | First day of reference month. |
| `geography_type` | character | `state`, `adjustment`, `region`, or `brazil`. |
| `code_region` | integer | IBGE major-region code for state, adjustment, or region; missing for Brazil. |
| `abbrev_state` | character | Two-letter state abbreviation; missing for other row types. |
| `code_state` | integer | IBGE state code; missing for other row types. |
| `value` | double | Tonnes; missing for unpublished state/month cells. |
| `unit` | character | Constant `tonnes`. |
| `source_kind` | character | `archive` or `snic_pdf`, for audit of the splice. |

## Delivery and caching

- Default `get_dataset("cement")` to the published `cement_consumption.rds` release snapshot through the existing `source = "auto"` memo/cache path; map the companion to `cement_production.rds`. This avoids downloading and parsing PDFs on ordinary CRAN use. [get_dataset.R](../../R/get_dataset.R), [cache_github.R](../../R/cache_github.R), [datasets.yaml](../../inst/extdata/datasets.yaml).
- Keep the full archive workbooks outside git while reuse terms remain unresolved. The pipeline takes an explicit archive directory or the `realestatebr.cement_archive_dir` option at run time, validates the A03/A04 hashes above, and builds both snapshots from those inputs and verified SNIC PDFs. Commit only small test excerpts and source metadata. Do not copy full workbooks into `inst/extdata`. [A03], [A04].
- Make `source = "fresh"` abort clearly in the first release; the archive lives outside the installed package, so an installed client cannot rebuild the full series. Add a true fresh path only after approved archive distribution in `inst/extdata`. Do not label a GitHub cache read as a fresh SNIC fetch. [get_dataset.R](../../R/get_dataset.R), [get_fgv_ibre.R](../../R/get_fgv_ibre.R).
- Hold publication of derived snapshot assets until the maintainer resolves SNIC's unstated reuse terms and the archived-workbook redistribution rights. The site's copyright footer supplies no licence. [SNIC index](https://snic.org.br/numeros-da-industria.php), [A03], [A04].

## Files to add/change

- Add a hash/provenance manifest without the full archive workbooks, an explicit-path PDF/index parser and archive reader plus cache getter in `R/get_cement.R`, and `pdftools` in DESCRIPTION Suggests. The pipeline accepts a runtime archive path or `realestatebr.cement_archive_dir`; installed users read the cache only. Reuse `rvest`/`xml2` for link discovery, `readxl` for archive sheets, `download_with_retry()` for retries, `fetch_github_release_asset()` for snapshots, and `cli` for failures. [DESCRIPTION](../../DESCRIPTION), [helpers_download.R](../../R/helpers_download.R), [cache_github.R](../../R/cache_github.R).
- Add the `cement` registry entry to `inst/extdata/datasets.yaml`, two file targets and validation in `_targets.R` / `data-raw/pipeline/`, and focused fixtures/tests under `tests/testthat/`. Review `R/get_dataset.R` only if the cache-only `fresh` behavior needs a new capability flag. [registry](../../inst/extdata/datasets.yaml), [pipeline](../../_targets.R), [tests](../../tests/testthat/).

## Test plan

- Save a small verbatim text fixture from each concept's real PDF page; assert title, 12 month headers, 27 named states, four adjustments, five regions, Brazil, exact sample values, and `-` handling. [2025 PDFs](https://snic.org.br/numeros-da-industria.php).
- Test archive parsing across 2003, 2004 fractional values, 2014–2016 missing states, 2024 full year, and 2025 January-only sheets. Assert `...` and blank never become zero. [A03], [A04].
- Lock the 2024 exact overlap and January 2025 production revision anchors above; verify source precedence, unique keys, row annual totals, state-plus-adjustment regional totals, and region-to-Brazil totals. [A03], [A04], [2025 production](https://snic.org.br/assets/pdf/numeros/1784570386.pdf).
- Feed changed month labels, extra/missing state, duplicated adjustment, malformed number, and broken totals to the parser; each must raise a named `cli::cli_abort()` error before a snapshot can be published.
- Phase 1 adds offline failing tests and runs AIR on the tests. After implementation, run focused and full package tests, `R CMD check`, and a built-tarball inspection before release. [DESCRIPTION](../../DESCRIPTION), [tests](../../tests/testthat/).

## Risks and open questions

- **Coverage:** ship explicit missing state rows for 2014-03–2016-12 and retain region/Brazil totals; document this gap in the dataset help. The annual reports supply annual state totals, but no checked source supplies the missing monthly state values. [A03], [A04], [2019 report](https://snic.org.br/assets/pdf/relatorio_anual/rel_anual_2019.pdf).
- **Rights gate:** SNIC's public pages do not state a reuse licence. Seek written terms for derived snapshots and permission for the archived workbook inputs before republishing either. [SNIC index](https://snic.org.br/numeros-da-industria.php), [A03], [A04].
- **Transport gate:** SNIC's leaf certificate expired on 2026-09-03; `openssl s_client` shows the YR1 intermediate is present. The pipeline must fail with a clear `cli` error naming the expired certificate, and PDF refresh remains blocked until SNIC renews it. A pinned CA bundle cannot fix expiration. Keep verification on; the maintainer will report the certificate in the permission email. [SNIC index](https://snic.org.br/numeros-da-industria.php).
- **Vintage risk:** PDF URLs and values may change without a dated release note. Record hashes and retrieval dates, and reject a year that loses already-published months. [SNIC index](https://snic.org.br/numeros-da-industria.php), [A04].

[A01]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.01_5.xlsx
[A02]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.02_3.xlsx
[A03]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.03_Consumo_cimento_53.xlsx
[A04]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.04_Produçao_cimento_52.xlsx
[A03-old]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.03_Consumo_cimento_52.xlsx
[A04-old]: /Users/viniciusreginatto/GitHub/realestatebr/data-raw/backlog/CBIC/tabela_07.A.04_Produçao_cimento_51.xlsx
