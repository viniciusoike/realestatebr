# Municipal IPTU and ITBI Tax Revenue

Annual municipal IPTU and ITBI revenue in nominal BRL from
SICONFI/FINBRA DCA Annex I-C, 2013-present, with the 2018
account-vintage break marked by account_scope; the Distrito Federal
(5300108) is excluded because it reports IPTU and ITBI only in its
state-level accounts.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"siconfi_taxes"`.

    siconfi_taxes <- get_dataset("siconfi_taxes")

## Source

Tesouro Nacional - SICONFI (DCA, Anexo I-C), FINBRA bulk files, and IBGE
population

## Details

- **Source**: Tesouro Nacional - SICONFI (DCA, Anexo I-C), FINBRA bulk
  files, and IBGE population

- **URL**: <https://apidatalake.tesouro.gov.br/ords/siconfi/tt/entes>

- **Geography**: Brazilian municipalities

- **Frequency**: annual

- **Coverage**: 2013-latest closed year

- **Access mode**: `materialized`

This dataset is cache-only: it is rebuilt by
data-raw/siconfi/build_snapshot.R from the maintainer's local FINBRA
bulk files (never in the repository) plus an API refresh of the latest
years, so source='fresh' and the fresh half of source='auto' do not
apply. Values are nominal BRL with a decimal-comma source parsed to the
cent; the 2013 FINBRA files include municipalities that filed QDCC
instead of DCA (São Paulo among them), accepted as published. The 2018
PCASP recode folds fines and old-debt lines into the tax parents, so the
pre-2018 tax line is not comparable with the post-2018 tax family;
account_scope marks the break and no cross-break total is reconstructed.
The Distrito Federal (5300108) is excluded from the municipality
universe because it reports IPTU and ITBI in its state-level accounts
and never in the municipal files. FUNDEB and constitutional-transfer
deduction columns never feed the tax deductions. A municipality-year-tax
with an observed gross row but no deduction row counts the deduction as
zero and computes net_revenue; deductions_reported records whether a
deduction row existed in the source. Municipalities absent from a year's
FINBRA file appear as non-reporters with reported=FALSE and NA tax and
revenue values; population does not depend on reporting. population and
the two revenue totals are the municipality-year context: population
comes from IBGE (yearly estimates until 2021 and from 2024, the 2022
Census count, and a 2023 midpoint interpolation; FINBRA's População
field is stale and lagged, so it is never used), it fills non-reporter
rows too, and population_source records where it came from; both revenue
totals are gross, before deductions, and the totals switch source for
refreshed API years.

## Columns

- code_muni:

  Seven-digit IBGE municipality code, geobr-compatible.

- abbrev_state:

  Two-letter state abbreviation as published by the source.

- year:

  Exercise year, 2013 to the latest closed year.

- population:

  Integer resident population from IBGE, independent of SICONFI
  reporting; repeated on both tax rows. The yearly estimate (SIDRA
  table 6579) for the other years, the 2022 Census count (table 4709)
  for 2022, and a 2023 midpoint between the 2022 Census and the 2024
  estimate; NA when IBGE has no figure for the year. The 2022 Census
  count sits well below the 2021 estimate in many municipalities, so
  per-capita series break in 2022.

- population_source:

  How population was obtained: estimate (yearly IBGE estimate, table
  6579), census (2022 Census count, table 4709), or interpolated (2023
  midpoint of the census and the 2024 estimate); NA when population is
  NA.

- current_revenue:

  Gross realized total current revenue (Receitas Correntes) in nominal
  BRL for the municipality-year, before any deduction; repeated on both
  tax rows. From FINBRA, replaced by the API values for refreshed years;
  NA when the municipality reported but lacks the account line.

- tax_revenue:

  Gross realized Impostos, Taxas e Contribuições de Melhoria (the whole
  tax group behind the IPTU and ITBI lines) in nominal BRL for the
  municipality-year, before deductions; repeated on both tax rows. From
  FINBRA, replaced by the API values for refreshed years; NA when the
  municipality reported but lacks the account line.

- tax:

  Tax identifier: iptu or itbi.

- reported:

  TRUE when the municipality appears in that year's data (FINBRA file or
  API refresh); non-reporters keep one NA row per tax.

- value_status:

  observed (tax row present), missing_tax_row (the municipality reported
  but this tax has no gross row), or non_reporter (absent from the
  year's data).

- gross_revenue:

  Realized gross tax-account value in nominal BRL; NA when the tax row
  is absent.

- other_deductions:

  Non-FUNDEB, non-transfer tax deductions in nominal BRL; 0 when the
  municipality-year-tax has an observed gross row but no deduction row
  in the source, otherwise the observed value, kept even when the gross
  row is missing.

- deductions_reported:

  TRUE when the source carried a deduction row for the
  municipality-year-tax; FALSE when only a gross row exists and the
  deduction is assumed 0; NA when the source has neither row.

- net_revenue:

  Gross revenue minus deductions, rounded to cents, computed whenever
  the gross row exists (an assumed 0 deduction is subtracted).

- account_scope:

  Account-vintage scope: legacy_line (IPTU and ITBI shown on separate
  account lines) through 2017, tax_family (post-2018 PCASP parents that
  fold in fines and old-debt lines) from 2018. Do not build a single
  constant-scope series across 2017-2018.

- source:

  Row provenance: finbra (bulk-file history) or api (SICONFI API refresh
  of the latest years); NA for non-reporter rows.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abecip`](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[`abrainc`](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[`bcb_realestate`](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`cement`](https://viniciusoike.github.io/realestatebr/reference/cement.md),
[`cno`](https://viniciusoike.github.io/realestatebr/reference/cno.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`mcmv`](https://viniciusoike.github.io/realestatebr/reference/mcmv.md),
[`paic`](https://viniciusoike.github.io/realestatebr/reference/paic.md),
[`pim_pf_construction`](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[`pnad_housing`](https://viniciusoike.github.io/realestatebr/reference/pnad_housing.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
