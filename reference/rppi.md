# Brazilian Residential Property Price Indices

Comprehensive collection of all Brazilian residential property price
indices.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"rppi"`.

    rppi <- get_dataset("rppi")
    rppi_ivgr <- get_dataset("rppi", table = "ivgr")

## Source

Multiple (FIPE/ZAP, IVGR, IGMI, IQA, IQAIW, IVAR, SECOVI-SP)

## Details

- **Source**: Multiple (FIPE/ZAP, IVGR, IGMI, IQA, IQAIW, IVAR,
  SECOVI-SP)

- **Geography**: Brazil

- **Frequency**: monthly

- **Coverage**: varies by index

- **Tables**: `"fipezap"`, `"ivgr"`, `"igmi"`, `"iqa"`, `"iqaiw"`,
  `"ivar"`, `"secovi_sp"`, `"sale"`, `"rent"`, `"all"` (default:
  `"fipezap"`)

Index methodologies vary by source; base periods normalized where
possible.

## Table "fipezap" (FIPE-ZAP Index)

FIPE-ZAP residential property price index. This is the default table.
Coverage: Major cities.

- date:

  Reference month.

- name_muni:

  City name or aggregate (e.g. Índice Fipezap).

- market:

  Market segment: residential or commercial.

- rent_sale:

  Transaction type: sale or rent.

- variable:

  Measure: index, chg, acum12m, price_m2, or yield.

- rooms:

  Number of bedrooms (total, 1, 2, 3, or 4).

- value:

  Value of the measure.

## Table "ivgr" (IVGR - Índice de Valores Gerais Residenciais)

General residential values index. Coverage: National.

- date:

  Reference month.

- name_geo:

  Geographic area (Brazil).

- index:

  Price index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "igmi" (IGMI - Índice Geral do Mercado Imobiliário)

General real estate market index. Coverage: São Paulo.

- date:

  Reference month.

- name_muni:

  City name or national aggregate.

- index:

  Price index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "iqa" (IQA - Índice QuintoAndar)

QuintoAndar rent price index. Coverage: Major cities.

- date:

  Reference month.

- name_muni:

  City name.

- index:

  Rent index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "iqaiw" (IQAIW - Índice QuintoAndar ImovelWeb)

QuintoAndar ImovelWeb hedonic rent price index. Coverage: Major cities
(6 cities).

- date:

  Reference month.

- name_muni:

  City name.

- rooms:

  Number of bedrooms (total, 1, 2, 3, or 4).

- index:

  Rent index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "ivar" (IVAR - Índice de Valores de Aluguéis Residenciais)

Residential rent values index. Coverage: National.

- date:

  Reference month.

- name_muni:

  City name or national aggregate.

- index:

  Rent index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "secovi_sp" (SECOVI-SP Index)

São Paulo real estate syndicate index. Coverage: São Paulo.

- date:

  Reference month.

- name_muni:

  City name (São Paulo).

- index:

  Rent index level.

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "sale" (Stacked Sale Indices)

Harmonized combination of all sale-related indices with source column.

- source:

  Index source: IVG-R, IGMI-R, or FipeZap.

- date:

  Reference month.

- name_muni:

  City name or aggregate (e.g. Brazil).

- index:

  Price index level (each source has its own base period).

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "rent" (Stacked Rent Indices)

Harmonized combination of all rent-related indices with source column.

- source:

  Index source: IVAR, IQAIW, or FipeZap.

- date:

  Reference month.

- name_muni:

  City name or aggregate (e.g. Brazil).

- index:

  Rent index level (each source has its own base period).

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

## Table "all" (All Indices Combined)

Complete stacked dataset with transaction_type indicator.

- source:

  Index source (e.g. IVG-R, IGMI-R, IVAR, IQAIW, FipeZap).

- date:

  Reference month.

- name_muni:

  City name or aggregate (e.g. Brazil).

- index:

  Index level (each source has its own base period).

- chg:

  Month-on-month change of the index.

- acum12m:

  Accumulated 12-month change of the index.

- transaction_type:

  Transaction type: sale or rent.

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
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
