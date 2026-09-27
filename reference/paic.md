# PAIC Construction Industry Data

Annual construction-industry activity, employment, revenue, costs, and
output for the new series starting in 2024.

Retrieve this dataset with
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
using the name `"paic"`.

    paic <- get_dataset("paic")
    paic_size <- get_dataset("paic", table = "size")

## Source

IBGE - Pesquisa Anual da Indústria da Construção

## Details

- **Source**: IBGE - Pesquisa Anual da Indústria da Construção

- **URL**: <https://sidra.ibge.gov.br/pesquisa/paic/tabelas>

- **Geography**: Brazil, geographic regions, and states (varies by
  table)

- **Frequency**: annual

- **Coverage**: 2024-present (new series; do not compare with 2007-2023)

- **Access mode**: `materialized`

- **Tables**: `"activity"`, `"size"`, `"state"` (default: `"activity"`)

New 2024-onward series per IBGE Nota técnica 01/2026; the 2024 series
break reflects the new Cadastro Básico de Seleção. Values publish in
original units, including thousand reais. Table 10463 covers all firms
at national level only; table 10442 covers firms with five or more
workers by headquarters or work location. The work-location basis of
variables 13808, 631, 673, 1245, and 1241 follows the PAIC 2024
publication (v. 34, June 2026), which collects the regional block by
Unidade da Federação de atuação da empresa. In table 10441, SIDRA marks
unpublished state cells in the total and 1-4 bands with a dash; these
rows are dropped rather than read as zeros.

## Table "activity" (Activity by Size Band)

General construction-enterprise data by firm-size band and CNAE activity
from SIDRA table 10463 (Brazil only, all firms). The hierarchy stacks
totals, divisions, groups, and classes in one tibble; filter by
activity_level to avoid double-counting. Detail differs by size band:
1-4 workers reaches divisions only, 5-29 adds groups, and 30+ reaches
classes. No category covers all sizes for a single division; the only
all-firm row is Total das empresas, so a national division total is the
sum of the three size bands. This is the default table. Coverage:
2024-present.

- year:

  Reference year.

- source_table:

  SIDRA table supplying the observation (10463).

- geography_type:

  Geographic level (brazil for this table).

- geography_code:

  IBGE code for the geographic unit.

- geography_name:

  Geographic unit name in Portuguese.

- size_band:

  Firm-size band: total, 1_4, 5_29, or 30_plus.

- activity_level:

  CNAE level: total, division, group, or class.

- activity_code:

  CNAE 2.0 code parsed from the category (e.g. 41, 41.1, 41.10); missing
  for totals.

- activity_name:

  Canonical CNAE activity name from the package lookup.

- division_code:

  Parent CNAE division code.

- group_code:

  Parent CNAE group code (for groups and classes).

- variable_id:

  SIDRA variable ID.

- variable:

  English series identifier (e.g. firms, employment, wages,
  construction_output).

- variable_name_pt:

  Original IBGE variable label in Portuguese.

- unit:

  Original IBGE unit, including thousand reais (Mil Reais) where
  specified.

- value:

  Observed value in the original unit; NA when the cell is not
  applicable, not available, or suppressed.

- value_raw:

  Original SIDRA cell text.

- value_status:

  Cell status: observed, zero (SIDRA -), not_applicable (..),
  not_available (...), suppressed (X), or missing.

## Table "size" (Size Bands by Geography)

General construction-enterprise data by firm-size band from SIDRA table
10441 (Brazil, regions, and states, all firms). State rows cover firms
with five or more workers only, because SIDRA does not publish state
figures for the total and 1-4 bands. Keeps the 16 level variables; the
16 share variables (percentual do total geral) are dropped because users
can derive them. Coverage: 2024-present.

- year:

  Reference year.

- source_table:

  SIDRA table supplying the observation (10441).

- geography_type:

  Geographic level: brazil, region, or state.

- geography_code:

  IBGE code for the geographic unit; interpret together with
  geography_type.

- geography_name:

  Geographic unit name in Portuguese.

- size_band:

  Firm-size band: total, 1_4, or 5_plus (states: 5_plus only).

- variable_id:

  SIDRA variable ID.

- variable:

  English series identifier (e.g. firms, employment, wages,
  construction_output).

- variable_name_pt:

  Original IBGE variable label in Portuguese.

- unit:

  Original IBGE unit, including thousand reais (Mil Reais) where
  specified.

- value:

  Observed value in the original unit; NA when the cell is not
  applicable, not available, or suppressed.

- value_raw:

  Original SIDRA cell text.

- value_status:

  Cell status: observed, zero (SIDRA -), not_applicable (..),
  not_available (...), suppressed (X), or missing.

## Table "state" (Large Firms by State)

Employment, wages, costs, and output for construction firms with five or
more workers from SIDRA table 10442 (Brazil, regions, and states). The
geography_basis column records whether the variable follows headquarters
(13807, origem-sede) or work location (all other variables, local de
atuação). Coverage: 2024-present.

- year:

  Reference year.

- source_table:

  SIDRA table supplying the observation (10442).

- geography_type:

  Geographic level: brazil, region, or state.

- geography_code:

  IBGE code for the geographic unit; interpret together with
  geography_type.

- geography_name:

  Geographic unit name in Portuguese.

- geography_basis:

  Geographic meaning: headquarters (variable 13807) or work_location
  (all other variables).

- variable_id:

  SIDRA variable ID.

- variable:

  English series identifier (e.g. employment, wages,
  construction_output). construction_and_development_costs (1245)
  includes development costs and differs from construction_costs in the
  other tables.

- variable_name_pt:

  Original IBGE variable label in Portuguese.

- unit:

  Original IBGE unit, including thousand reais (Mil Reais) where
  specified.

- value:

  Observed value in the original unit; NA when the cell is not
  applicable, not available, or suppressed.

- value_raw:

  Original SIDRA cell text.

- value_status:

  Cell status: observed, zero (SIDRA -), not_applicable (..),
  not_available (...), suppressed (X), or missing.

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
[`pim_pf_construction`](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
