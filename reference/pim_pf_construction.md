# PIM-PF Construction-input Production Index

Linked monthly physical-production index for inputs typically used in
construction.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"pim_pf_construction"`.

    pim_pf_construction <- get_dataset("pim_pf_construction")

## Source

IBGE - Pesquisa Industrial Mensal - Produção Física

## Details

- **Source**: IBGE - Pesquisa Industrial Mensal - Produção Física

- **URL**: <https://apisidra.ibge.gov.br/desctabapi.aspx?c=8886>

- **Geography**: Brazil

- **Frequency**: monthly

- **Coverage**: January 1991-present

- **Access mode**: `materialized`

The 1991-2011 series from SIDRA table 2294 is linked to table 8886 using
their full 2012 overlap.

## Columns

- date:

  First day of the reference month.

- variable:

  Series identifier: construction_inputs_production_index.

- reference_period:

  Reference period of the linked index: 2022 average = 100.

- source_table:

  SIDRA table supplying the observation: 2294 before 2012 and 8886 from
  2012 onward.

- value:

  Linked physical-production index. Values before 2012 are rescaled by
  the ratio of the two source series' 2012 annual means.

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
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
