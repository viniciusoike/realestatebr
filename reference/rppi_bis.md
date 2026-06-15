# BIS Residential Property Price Indices

International residential property price indices from Bank for
International Settlements.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"rppi_bis"`.

    rppi_bis <- get_dataset("rppi_bis")
    rppi_bis_detailed_monthly <- get_dataset("rppi_bis", table = "detailed_monthly")

## Source

Bank for International Settlements

## Details

- **Source**: Bank for International Settlements

- **URL**: <https://data.bis.org/topics/RPP>

- **Geography**: International (60+ countries including Brazil)

- **Frequency**: quarterly

- **Coverage**: 1970-present (varies by country)

- **Tables**: `"selected"`, `"detailed_monthly"`,
  `"detailed_quarterly"`, `"detailed_annual"`, `"detailed_halfyearly"`
  (default: `"selected"`)

International data; minimal translation needed.

## Table "selected" (Selected Series)

Core RPPI series for major countries. This is the default table.

- date:

  Reference quarter (first day of the quarter).

- ref_area_code:

  Country or area code (aggregates use BIS codes such as 4T).

- ref_area_name:

  Country or area name.

- unit:

  Measure: index (2010 = 100) or yoy_chg (year-on-year change, percent).

- unit_name:

  Full description of the unit of measure.

- is_nominal:

  1 for nominal series, 0 for CPI-deflated (real) series.

- series_code:

  BIS series identifier.

- value:

  Series value.

## Table "detailed_monthly" (Detailed Monthly)

Monthly detailed RPPI data.

- date:

  Reference period.

- year:

  Reference year.

- series_code:

  BIS series identifier.

- ref_area_code:

  Country or area code.

- ref_area_name:

  Country or area name.

- re_type_code:

  Property type code.

- re_type_name:

  Property type (e.g. all types, new or existing dwellings).

- re_vintage_code:

  Property vintage code.

- re_vintage_name:

  Property vintage (new versus existing).

- compiling_org_code:

  Compiling organisation code.

- compiling_org_name:

  Compiling organisation.

- priced_unit_code:

  Priced unit code.

- priced_unit_name:

  Priced unit (e.g. dwelling, square metre).

- seas_adjust_code:

  Seasonal adjustment code.

- seas_adjust_name:

  Seasonal adjustment description.

- availability_code:

  Series availability code.

- availability_name:

  Series availability description.

- unit_code:

  Unit of measure code.

- unit_name:

  Unit of measure description.

- unit_mult_code:

  Unit multiplier code.

- unit_mult_name:

  Unit multiplier description.

- value:

  Series value.

Frequency-specific period columns (month, quarter, or semester) and a
few metadata columns vary slightly across the detailed tables.

## Table "detailed_quarterly" (Detailed Quarterly)

Quarterly detailed RPPI data.

- date:

  Reference period.

- year:

  Reference year.

- series_code:

  BIS series identifier.

- ref_area_code:

  Country or area code.

- ref_area_name:

  Country or area name.

- re_type_code:

  Property type code.

- re_type_name:

  Property type (e.g. all types, new or existing dwellings).

- re_vintage_code:

  Property vintage code.

- re_vintage_name:

  Property vintage (new versus existing).

- compiling_org_code:

  Compiling organisation code.

- compiling_org_name:

  Compiling organisation.

- priced_unit_code:

  Priced unit code.

- priced_unit_name:

  Priced unit (e.g. dwelling, square metre).

- seas_adjust_code:

  Seasonal adjustment code.

- seas_adjust_name:

  Seasonal adjustment description.

- availability_code:

  Series availability code.

- availability_name:

  Series availability description.

- unit_code:

  Unit of measure code.

- unit_name:

  Unit of measure description.

- unit_mult_code:

  Unit multiplier code.

- unit_mult_name:

  Unit multiplier description.

- value:

  Series value.

## Table "detailed_annual" (Detailed Annual)

Annual detailed RPPI data.

- date:

  Reference period.

- year:

  Reference year.

- series_code:

  BIS series identifier.

- ref_area_code:

  Country or area code.

- ref_area_name:

  Country or area name.

- re_type_code:

  Property type code.

- re_type_name:

  Property type (e.g. all types, new or existing dwellings).

- re_vintage_code:

  Property vintage code.

- re_vintage_name:

  Property vintage (new versus existing).

- compiling_org_code:

  Compiling organisation code.

- compiling_org_name:

  Compiling organisation.

- priced_unit_code:

  Priced unit code.

- priced_unit_name:

  Priced unit (e.g. dwelling, square metre).

- seas_adjust_code:

  Seasonal adjustment code.

- seas_adjust_name:

  Seasonal adjustment description.

- availability_code:

  Series availability code.

- availability_name:

  Series availability description.

- unit_code:

  Unit of measure code.

- unit_name:

  Unit of measure description.

- unit_mult_code:

  Unit multiplier code.

- unit_mult_name:

  Unit multiplier description.

- value:

  Series value.

## Table "detailed_halfyearly" (Detailed Half-yearly)

Half-yearly detailed RPPI data.

- date:

  Reference period.

- year:

  Reference year.

- series_code:

  BIS series identifier.

- ref_area_code:

  Country or area code.

- ref_area_name:

  Country or area name.

- re_type_code:

  Property type code.

- re_type_name:

  Property type (e.g. all types, new or existing dwellings).

- re_vintage_code:

  Property vintage code.

- re_vintage_name:

  Property vintage (new versus existing).

- compiling_org_code:

  Compiling organisation code.

- compiling_org_name:

  Compiling organisation.

- priced_unit_code:

  Priced unit code.

- priced_unit_name:

  Priced unit (e.g. dwelling, square metre).

- seas_adjust_code:

  Seasonal adjustment code.

- seas_adjust_name:

  Seasonal adjustment description.

- availability_code:

  Series availability code.

- availability_name:

  Series availability description.

- unit_code:

  Unit of measure code.

- unit_name:

  Unit of measure description.

- unit_mult_code:

  Unit multiplier code.

- unit_mult_name:

  Unit multiplier description.

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
[`bcb_series`](https://viniciusoike.github.io/realestatebr/reference/bcb_series.md),
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
