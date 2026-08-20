# ABRAINC-FIPE Primary Market Indicators

Primary real estate market indicators from a panel of large developers,
covering launches, sales, and business conditions.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"abrainc"`.

    abrainc <- get_dataset("abrainc")
    abrainc_radar <- get_dataset("abrainc", table = "radar")

## Source

ABRAINC/FIPE

## Details

- **Source**: ABRAINC/FIPE

- **URL**: <https://www.fipe.org.br/pt-br/indices/abrainc>

- **Geography**: Brazil (major cities)

- **Frequency**: quarterly

- **Coverage**: 2014-present

- **Tables**: `"indicator"`, `"radar"`, `"leading"` (default:
  `"indicator"`)

Social Housing (MCMV) refers to Minha Casa Minha Vida and Casa Verde
Amarela programs.

## Table "indicator" (Market Indicators)

Broad numbers of launches, sales, supply in the primary market. This is
the default table.

- date:

  Reference month.

- year:

  Reference year.

- category:

  Indicator group (e.g. new_units, sold, delivered).

- variable:

  Market segment: total, market_rate, or social_housing (MCMV and
  related programs).

- value:

  Number of units.

- variable_label:

  Human-readable label for variable.

## Table "radar" (Business Radar)

0-10 standardized index for general business conditions.

- date:

  Reference month.

- year:

  Reference year.

- category:

  Radar dimension (e.g. macro, credit, demand).

- variable:

  Indicator within the dimension (e.g. confidence, activity, interest).

- source:

  Source of the underlying series (e.g. FGV, BCB).

- value:

  Standardized 0-10 score.

- avg_category:

  Average score of the category over the full sample.

- avg_year_category:

  Average score of the category in the year.

- avg_year_variable:

  Average score of the variable in the year.

- ma3:

  3-month moving average of value.

- ma6:

  6-month moving average of value.

- variable_label:

  Human-readable label for variable.

## Table "leading" (Leading Indicator)

Building permits in São Paulo as real estate leading indicator.

- date:

  Reference month.

- year:

  Reference year.

- variable:

  Series identifier: leading_index, leading_index_12m, or alvaras_total
  (building permits).

- zone:

  São Paulo city zone (Total, Centro, Zona Norte, and others).

- value:

  Series value; index points, percent change, or permit counts depending
  on variable.

- variable_label:

  Human-readable label for variable.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abecip`](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[`bcb_realestate`](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
