# FGTS/MCMV Housing Finance and Subsidized Projects

Published financing observations, official financing summaries, and
subsidized housing project records.

Retrieve this dataset with
[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md)
using the name `"mcmv"`.

    mcmv <- query_dataset("mcmv")
    mcmv$financing

## Source

Ministério das Cidades - Secretaria Nacional de Habitação

## Details

- **Source**: Ministério das Cidades - Secretaria Nacional de Habitação

- **URL**:
  <https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/bases-de-dados-do-programa-minha-casa-minha-vida>

- **Geography**: Brazil

- **Frequency**: dated full snapshots

- **Coverage**: Contracts signed from 2009 onward; each snapshot reports
  its own reference dates

- **Access mode**: `query`

- **Tables**: `"financing"`, `"financing_summary"`,
  `"subsidized_projects"`

Source categories, missing observations, duplicates, and anomalies are
retained. See the [working
article](https://viniciusoike.github.io/realestatebr/articles/working-with-mcmv.md)
and [data
dictionary](https://viniciusoike.github.io/realestatebr/articles/mcmv-data-dictionary.md).

## Table "financing" (Financing)

One published financing observation, usually one housing unit. The
source has no unique key.

- reference_date:

  Reference date reported inside the source; not retrieval or
  publication date.

- code_muni_6:

  Six-digit IBGE municipality identifier without its check digit.

- name_muni:

  Municipality name as published, including whitespace and
  capitalization.

- state:

  Source state abbreviation.

- region:

  Source Brazilian region label; capitalization is preserved.

- contract_date:

  Financing contract signature date.

- units_financed:

  Number of financed housing units reported in this observation.

- amount_financed:

  Financing amount, in nominal BRL.

- subsidy_fgts_discount:

  FGTS discount subsidy, in nominal BRL.

- subsidy_ogu_discount:

  Federal budget (OGU) discount subsidy, in nominal BRL.

- subsidy_fgts_interest:

  FGTS interest-equilibrium subsidy, in nominal BRL.

- subsidy_ogu_interest:

  OGU interest-equilibrium subsidy, in nominal BRL.

- purchase_price:

  Property purchase value, in nominal BRL.

- household_income:

  Reported household income, in nominal BRL; no frequency inferred.

- financing_program:

  Source financing program label, including programs outside MCMV/CVA.

- interest_rate:

  Source interest rate in percentage units; periodicity is not inferred.

- property_type:

  Source property-type label, preserving capitalization variants.

- fgts_account_holder:

  Source FGTS account-holder code, retained as character; not a Boolean.

- amortization_system:

  Source amortization-system label.

- birth_date:

  Reported borrower birth date; unpublished in July analytical layout.

- income_band:

  Source income-band label or code; no undocumented code crosswalk is
  applied.

- project_name:

  Source development name; unpublished in July financing layout.

- sex:

  Source sex code; unpublished in March analytical layout.

## Table "financing_summary" (Financing Summary)

Official totals by municipality, year, month, and income band.

- reference_date:

  Reference date reported inside the source; not retrieval or
  publication date.

- code_muni_6:

  Six-digit IBGE municipality identifier without its check digit.

- name_muni:

  Municipality name as published, including whitespace and
  capitalization.

- state:

  Source state abbreviation.

- region:

  Source Brazilian region label; capitalization is preserved.

- contract_year:

  Source financing year; missing years are retained.

- contract_month:

  Source financing month; absent in annual summaries.

- units_financed:

  Number of financed housing units reported in this observation.

- amount_financed:

  Financing amount, in nominal BRL.

- subsidy_total:

  Official total subsidy in nominal BRL; July reconciles to all four
  analytical subsidy components.

- income_band:

  Source income-band label or code; no undocumented code crosswalk is
  applied.

## Table "subsidized_projects" (Subsidized Projects)

One published subsidized-project record. Duplicate rows and missing
operation codes are retained.

- reference_date:

  Reference date reported inside the source; not retrieval or
  publication date.

- code_muni_6:

  Six-digit IBGE municipality identifier without its check digit.

- name_muni:

  Municipality name as published, including whitespace and
  capitalization.

- state:

  Source state abbreviation.

- region:

  Source Brazilian region label; capitalization is preserved.

- contract_date:

  Project contract signature date.

- operation_code:

  Source operation identifier; missing and repeated values are retained.
  Not a primary key.

- project_name:

  Source development name.

- financial_agent:

  Source financial-agent name.

- modality:

  Source housing modality label.

- project_status:

  Source project-status label.

- units_contracted:

  Reported contracted housing units, including repeated source records.

- units_delivered:

  Reported delivered housing units.

- units_outstanding:

  Reported active outstanding housing units.

- units_cancelled:

  Reported cancelled housing units; missing counts are not zero.

- amount_contracted:

  Total project contract amount, in nominal BRL.

- amount_disbursed:

  Disbursed project amount, in nominal BRL.

- responsible_entity_cnpj:

  Source CNPJ of construction company or social entity, stored as
  character.

- responsible_entity_name:

  Source name of construction company or social entity.

- address:

  Source project address.

- postal_code:

  Source postal code (CEP), stored as character.

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
[`paic`](https://viniciusoike.github.io/realestatebr/reference/paic.md),
[`pim_pf_construction`](https://viniciusoike.github.io/realestatebr/reference/pim_pf_construction.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md),
[`sinapi`](https://viniciusoike.github.io/realestatebr/reference/sinapi.md)
