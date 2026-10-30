# SNIC Cement: Apparent Consumption and Production

Monthly cement apparent consumption and production in Brazil by state
and region.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"cement"`.

    cement <- get_dataset("cement")
    cement_production <- get_dataset("cement", table = "production")

## Source

SNIC - Sindicato Nacional da Indústria do Cimento

## Details

- **Source**: SNIC - Sindicato Nacional da Indústria do Cimento

- **URL**: <https://snic.org.br/numeros-da-industria.php>

- **Geography**: Brazil, five regions, 27 states, and unattributed
  regional adjustments

- **Frequency**: monthly

- **Coverage**: 2003-present; state observations are missing from
  2014-03 through 2016-12

- **Access mode**: `materialized`

- **Tables**: `"consumption"`, `"production"` (default: `"consumption"`)

Ajustes are regional estimates not attributed to states. State values
are missing from March 2014 through December 2016, although region and
Brazil totals remain. Across this gap, state comparisons are uncertain
because the unattributed Ajustes share rose from about 5% to about 13%
of Brazil consumption. Preliminary values are subject to revision. The
archive and PDFs have no stated redistribution licence; snapshots must
not be published until rights are cleared.

## Columns

All tables share the structure below; the `table` argument filters which
series are returned.

- date:

  First day of the reference month.

- geography_type:

  State, adjustment, region, or Brazil row; totals must not be summed
  with their components.

- code_region:

  IBGE major-region code; missing for Brazil.

- abbrev_state:

  Two-letter state abbreviation; missing for other geography types.

- code_state:

  IBGE state code; missing for other geography types.

- value:

  Cement quantity in tonnes; NA means unavailable or not yet published.

- unit:

  Constant tonnes.

- source_kind:

  Archive through 2023 or SNIC regional PDF from 2024.

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
[`pnad_housing`](https://viniciusoike.github.io/realestatebr/reference/pnad_housing.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
