# BCB Real Estate Market Data

Detailed real estate credit and market series from the Brazilian Central
Bank.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"bcb_realestate"`.

    bcb_realestate <- get_dataset("bcb_realestate")
    bcb_realestate_accounting <- get_dataset("bcb_realestate", table = "accounting")

## Source

Banco Central do Brasil

## Details

- **Source**: Banco Central do Brasil

- **URL**:
  <https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario>

- **Geography**: Brazil (by state)

- **Frequency**: monthly

- **Coverage**: 2001-present (varies by category)

- **Tables**: `"accounting"`, `"application"`, `"indices"`, `"sources"`,
  `"units"` (default: `"all"`)

Complex multi-level series structure; v1-v5 columns contain series
components.

## Columns

All tables share the structure below; the `table` argument filters which
series are returned.

- date:

  End-of-month reference date (last day of the month).

- category:

  Top-level series grouping (e.g. credito, contabil, direcionamento,
  fontes, imoveis).

- type:

  Series subtype within the category (e.g. estoque, contratacao,
  financiamento).

- v1:

  Series identifier component 1; meaning varies by series (e.g.
  carteira, borrower type, region).

- v2:

  Series identifier component 2 (e.g. br, pf, pj).

- v3:

  Series identifier component 3 (e.g. credit line such as sfh, fgts,
  home-equity).

- v4:

  Series identifier component 4 (often a state abbreviation or credit
  line).

- v5:

  Series identifier component 5 (often a state abbreviation or br).

- series_info:

  Full underscore-separated series identifier; together with date it
  uniquely identifies an observation.

- value:

  Series value; unit varies by series (R\$, units, or percent).

- year:

  Reference year.

- month:

  Reference month (1-12).

- abbrev_state:

  Two-letter state abbreviation, or BR for the national aggregate.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abecip`](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[`abrainc`](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
