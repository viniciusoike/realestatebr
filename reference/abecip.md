# ABECIP Housing Credit Indicators

Housing credit data from Brazilian housing finance system (SFH)
including SBPE flows, financed units, and home equity loans.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"abecip"`.

    abecip <- get_dataset("abecip")
    abecip_units <- get_dataset("abecip", table = "units")

## Source

ABECIP - Associação Brasileira das Entidades de Crédito Imobiliário

## Details

- **Source**: ABECIP - Associação Brasileira das Entidades de Crédito
  Imobiliário

- **URL**: <https://www.abecip.org.br>

- **Geography**: Brazil

- **Frequency**: monthly

- **Coverage**: 1982-present (varies by category)

- **Tables**: `"sbpe"`, `"units"`, `"cgi"` (default: `"sbpe"`)

Column names translated from Portuguese to English following standard
patterns.

## Table "sbpe" (SBPE Monetary Flows)

Monetary flows from SBPE (Sistema Brasileiro de Poupança e Empréstimo).
This is the default table. Coverage: January 1982-present.

- date:

  Reference month.

- sbpe_inflow:

  Deposits into SBPE savings accounts during the month (R\$ million;
  historical values in the currency of the period).

- sbpe_outflow:

  Withdrawals from SBPE savings accounts during the month (R\$ million).

- sbpe_netflow:

  Net savings flow: inflow minus outflow (R\$ million).

- sbpe_netflow_pct:

  Net flow as a share of the SBPE savings stock.

- sbpe_yield:

  Interest credited to SBPE savings accounts (R\$ million).

- sbpe_stock:

  End-of-month SBPE savings stock (R\$ million).

- rural_inflow:

  Deposits into rural savings accounts during the month (R\$ million).

- rural_outflow:

  Withdrawals from rural savings accounts during the month (R\$
  million).

- rural_netflow:

  Net rural savings flow: inflow minus outflow (R\$ million).

- rural_netflow_pct:

  Net rural flow as a share of the rural savings stock.

- rural_yield:

  Interest credited to rural savings accounts (R\$ million).

- rural_stock:

  End-of-month rural savings stock (R\$ million).

- total_stock:

  Combined SBPE and rural savings stock (R\$ million).

- total_netflow:

  Combined SBPE and rural net savings flow (R\$ million).

## Table "units" (Financed Units)

Number of units financed by SBPE, split by construction and acquisition.
Coverage: January 2002-present.

- date:

  Reference month.

- units_construction:

  Number of units financed for construction.

- units_acquisition:

  Number of units financed for acquisition.

- units_total:

  Total number of financed units.

- currency_construction:

  Value of construction financing (R\$ million).

- currency_acquisition:

  Value of acquisition financing (R\$ million).

- currency_total:

  Total value of financing (R\$ million).

## Table "cgi" (Home Equity Loans (CGI))

Summary data on home equity loans including default rates and average
terms. Coverage: January 2017-present.

- year:

  Reference year.

- date:

  Reference month.

- new_contracts:

  Number of new home equity loan contracts signed in the month.

- stock_contracts:

  Number of outstanding contracts at the end of the month.

- loan:

  Value of new loans granted in the month (R\$).

- outstanding_balance:

  Outstanding loan balance at the end of the month (R\$).

- average_term:

  Average contract term (months).

- default_rate:

  Share of loans in default (percent).

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md),
[`list_datasets()`](https://viniciusoike.github.io/realestatebr/reference/list_datasets.md),
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)

Other datasets:
[`abrainc`](https://viniciusoike.github.io/realestatebr/reference/abrainc.md),
[`bcb_realestate`](https://viniciusoike.github.io/realestatebr/reference/bcb_realestate.md),
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
