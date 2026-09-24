# SINAPI Construction Costs and Indices

Monthly construction costs, cost indices, and percentage changes, with
and without payroll-tax relief.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"sinapi"`.

    sinapi <- get_dataset("sinapi")

## Source

IBGE - Sistema Nacional de Pesquisa de Custos e Índices da Construção
Civil

## Details

- **Source**: IBGE - Sistema Nacional de Pesquisa de Custos e Índices da
  Construção Civil

- **URL**: <https://sidra.ibge.gov.br/tabela/2296>

- **Geography**: Brazil, geographic regions, and states

- **Frequency**: monthly

- **Coverage**: March 1986-present (varies by variable and
  payroll-relief treatment)

- **Access mode**: `materialized`

Payroll-relief series come from SIDRA table 2296 and series without
payroll relief from table 6586. The R\$/m² level starts in September
2012 with relief and January 2017 without relief; earlier coverage
applies only to index variables.

## Columns

- date:

  First day of the reference month.

- geography_type:

  Geographic level: brazil, region, or state.

- geography_code:

  IBGE code for the geographic unit; interpret together with
  geography_type.

- geography_name:

  Geographic unit name in Portuguese.

- payroll_relief:

  Whether the series includes payroll-tax relief (desoneração da folha
  de pagamento).

- variable:

  Series identifier: cost, materials_cost, labor_cost, cost_index,
  materials_index, labor_index, monthly_change, year_to_date_change, or
  twelve_month_change.

- variable_label:

  Original IBGE variable label in Portuguese.

- unit:

  Original IBGE unit: Reais for costs, Número-índice for indices, and a
  percent sign for changes.

- value:

  Observed value. Missing, unavailable, and suppressed observations are
  omitted.

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
[`cno`](https://viniciusoike.github.io/realestatebr/reference/cno.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`pim_pf_construction`](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
