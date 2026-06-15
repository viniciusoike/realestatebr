# BCB Economic Series

General economic and real estate related time series from Brazilian
Central Bank.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"bcb_series"`.

    bcb_series <- get_dataset("bcb_series")
    bcb_series_primary <- get_dataset("bcb_series", table = "primary")

## Source

Banco Central do Brasil - SGS

## Details

- **Source**: Banco Central do Brasil - SGS

- **URL**: <https://www3.bcb.gov.br/sgspub>

- **Geography**: Brazil

- **Frequency**: varies (daily/monthly/quarterly)

- **Coverage**: varies by series

- **Tables**: `"core"`, `"primary"`, `"secondary"`, `"tertiary"`,
  `"full"` (default: `"core"`)

Metadata available in both Portuguese and English.

## Columns

All tables share the structure below; the `table` argument filters which
series are returned.

- date:

  Reference date (frequency varies by series).

- code_bcb:

  Numeric code of the series in the BCB SGS system.

- name_simplified:

  Short series identifier; see the bundled bcb_metadata table for full
  names and units.

- value:

  Series value.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abecip`](https://viniciusoike.github.io/realestatebr/reference/abecip.md),
[`abrainc`](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[`bcb_realestate`](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
