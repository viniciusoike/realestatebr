# SECOVI-SP Real Estate Market Data

São Paulo real estate market indicators including condominium fees,
rentals, launches, and sales.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"secovi"`.

    secovi <- get_dataset("secovi")
    secovi_condo <- get_dataset("secovi", table = "condo")

## Source

SECOVI-SP - Sindicato da Habitação

## Details

- **Source**: SECOVI-SP - Sindicato da Habitação

- **URL**: <https://www.secovi.com.br>

- **Geography**: São Paulo

- **Frequency**: monthly

- **Coverage**: 2004-present (varies by category)

- **Tables**: `"condo"`, `"rent"`, `"launch"`, `"sale"` (default:
  `"all"`)

Regional classifications specific to São Paulo metropolitan area.

## Columns

All tables share the structure below; the `table` argument filters which
series are returned.

- date:

  Reference month.

- category:

  Market segment: condo, rent, launch, or sale.

- variable:

  Indicator within the category (e.g. icon, default_condominio,
  acao_locaticia).

- name:

  Breakdown dimension of the indicator (region, property type, or
  total).

- value:

  Indicator value; unit varies by variable.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abecip`](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[`abrainc`](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[`bcb_realestate`](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md)
