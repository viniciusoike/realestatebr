# PNAD Contínua Housing

Annual household tenure, dwelling type, household size, and
domestic-unit composition estimates from PNAD Contínua.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"pnad_housing"`.

    pnad_housing <- get_dataset("pnad_housing")
    pnad_housing_dwelling_type <- get_dataset("pnad_housing", table = "dwelling_type")

## Source

IBGE - Pesquisa Nacional por Amostra de Domicílios Contínua anual

## Details

- **Source**: IBGE - Pesquisa Nacional por Amostra de Domicílios
  Contínua anual

- **URL**: <https://sidra.ibge.gov.br/pesquisa/pnadca/tabelas>

- **Geography**: Brazil, geographic regions, states, state capitals,
  published metropolitan regions, and published integrated-development
  regions

- **Frequency**: annual

- **Coverage**: 2016-2025 for housing-module tables, excluding
  2020-2021; 2012-2025 for household composition

- **Access mode**: `materialized`

- **Tables**: `"tenure"`, `"dwelling_type"`, `"household_size"`,
  `"mean_household_size"`, `"household_composition"` (default:
  `"tenure"`)

Counts remain in thousand households, percentages remain on a 0-100
scale, and coefficients of variation are separate measures. Total
categories coexist with component categories and must be excluded before
summing components. Housing-module tables have no 2020-2021
observations. Household composition describes relationships to the
reference person, not a number of families; its published count rows are
restricted to total reference-person sex. Geography labels retain the
boundary-vintage text published by IBGE.

## Columns

All tables share the structure below; the `table` argument filters which
series are returned.

- year:

  Reference year.

- source_table:

  SIDRA table supplying the observation.

- geography_type:

  Geographic level: brazil, region, state, capital, metropolitan_region,
  or integrated_development_region.

- geography_code:

  IBGE code for the geographic unit; interpret together with
  geography_type.

- geography_name:

  Geographic unit name in Portuguese, including the source
  boundary-vintage text.

- geography_level_name:

  Original SIDRA geographic-level label in Portuguese.

- classification_id:

  SIDRA classification ID; missing for mean_household_size.

- category_id:

  SIDRA category ID; missing for mean_household_size.

- category:

  Stable English category identifier; missing for mean_household_size.

- category_name_pt:

  Original SIDRA category label in Portuguese; missing for
  mean_household_size.

- variable_id:

  SIDRA variable ID.

- variable:

  Stable English measure identifier.

- variable_name_pt:

  Original IBGE variable label in Portuguese.

- unit:

  Original IBGE unit: Mil unidades, Pessoas, or percent.

- value:

  Observed value in the original unit; NA when the cell is not
  applicable, not available, suppressed, or missing.

- value_raw:

  Original SIDRA cell text.

- value_status:

  Cell status: observed, zero, not_applicable, not_available,
  suppressed, or missing.

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
[`mcmv`](https://viniciusoike.github.io/realestatebr/reference/mcmv.md),
[`paic`](https://viniciusoike.github.io/realestatebr/reference/paic.md),
[`pim_pf_construction`](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
