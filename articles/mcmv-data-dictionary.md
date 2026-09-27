# MCMV data dictionary

This dictionary defines the three MCMV tables returned by
`query_dataset("mcmv")`. The column tables below come from the package
registry, the same source as the
[`?mcmv`](https://viniciusoike.github.io/realestatebr/reference/mcmv.md)
help page. The [working
article](https://viniciusoike.github.io/realestatebr/articles/working-with-mcmv.md)
shows how to query the tables.

The source is the Ministério das Cidades’ [MCMV open-data
page](https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/bases-de-dados-do-programa-minha-casa-minha-vida).
Its official [data
dictionary](https://www.gov.br/cidades/pt-br/acesso-a-informacao/acoes-e-programas/habitacao/programa-minha-casa-minha-vida/minha-casa-minha-vida-fnhis-sub-50-1/arquivos-fnhis-sub-50/Dicionarios_SNH_2025_10_09.pdf)
(version 2.4, October 2025) predates the July 2026 files and does not
describe several of their changes. The notes below record where the
published files depart from it.

## Conventions

- **Names.** Columns use English names. Measures share prefixes:
  `units_*` for housing units, `amount_*` for financed, contracted, or
  disbursed amounts, and `subsidy_<source>_<component>` for subsidy
  components.
- **Money.** Amounts are nominal BRL, stored as doubles without
  rounding.
- **Municipalities.** `code_muni_6` is the six-digit IBGE code, without
  the check digit. `name_muni`, `state`, and `region` keep the source’s
  spelling and capitalization.
- **Dates.** `reference_date` is the date the source reports for its own
  extract, not the download or publication date. Contract dates come
  from timestamps that are always midnight, so they are stored as dates.
- **Missing values.** `NA` means the source left the value blank, or the
  release did not publish the column at all. The package never fills in
  missing values, from zero or from older snapshots.
- **Categories.** Labels and codes appear as published, including
  inconsistent capitalization. The package applies no crosswalk the
  source does not document.

## `financing`

One published financing observation, usually one housing unit. The
source has no unique key. In the July 2026 release, every row reports
exactly one unit.

| Column | Source header | Type | Unit | Definition |
|:---|:---|:---|:---|:---|
| `reference_date` | `data_referencia` | DATE | calendar date | Reference date reported inside the source; not retrieval or publication date. |
| `code_muni_6` | `cod_ibge` | VARCHAR | identifier or source label | Six-digit IBGE municipality identifier without its check digit. |
| `name_muni` | `txt_municipio` | VARCHAR | identifier or source label | Municipality name as published, including whitespace and capitalization. |
| `state` | `txt_uf` | VARCHAR | identifier or source label | Source state abbreviation. |
| `region` | `txt_regiao` | VARCHAR | identifier or source label | Source Brazilian region label; capitalization is preserved. |
| `contract_date` | `data_assinatura_financiamento` | DATE | calendar date | Financing contract signature date. |
| `units_financed` | `qtd_uh_financiadas` | INTEGER | housing units | Number of financed housing units reported in this observation. |
| `amount_financed` | `vlr_financiamento` | DOUBLE | nominal BRL | Financing amount, in nominal BRL. |
| `subsidy_fgts_discount` | `vlr_subsidio_desconto_fgts` | DOUBLE | nominal BRL | FGTS discount subsidy, in nominal BRL. |
| `subsidy_ogu_discount` | `vlr_subsidio_desconto_ogu` | DOUBLE | nominal BRL | Federal budget (OGU) discount subsidy, in nominal BRL. |
| `subsidy_fgts_interest` | `vlr_subsidio_equilíbrio_fgts` | DOUBLE | nominal BRL | FGTS interest-equilibrium subsidy, in nominal BRL. |
| `subsidy_ogu_interest` | `vlr_subsidio_equilíbrio_ogu` | DOUBLE | nominal BRL | OGU interest-equilibrium subsidy, in nominal BRL. |
| `purchase_price` | `vlr_compra` | DOUBLE | nominal BRL | Property purchase value, in nominal BRL. |
| `household_income` | `vlr_renda_familiar` | DOUBLE | nominal BRL | Reported household income, in nominal BRL; no frequency inferred. |
| `financing_program` | `txt_programa_fgts` | VARCHAR | identifier or source label | Source financing program label, including programs outside MCMV/CVA. |
| `interest_rate` | `num_taxa_juros` | DOUBLE | source percentage units | Source interest rate in percentage units; periodicity is not inferred. |
| `property_type` | `txt_tipo_imovel` | VARCHAR | identifier or source label | Source property-type label, preserving capitalization variants. |
| `fgts_account_holder` | `bln_cotista` | VARCHAR | identifier or source label | Source FGTS account-holder code, retained as character; not a Boolean. |
| `amortization_system` | `txt_sistema_amortizacao` | VARCHAR | identifier or source label | Source amortization-system label. |
| `birth_date` | `dte_nascimento` | DATE | calendar date | Reported borrower birth date; unpublished in July analytical layout. |
| `income_band` | `txt_compatibilidade_faixa_renda` | VARCHAR | identifier or source label | Source income-band label or code; no undocumented code crosswalk is applied. |
| `project_name` | `txt_nome_empreendimento` | VARCHAR | identifier or source label | Source development name; unpublished in July financing layout. |
| `sex` | `co_sexo` | VARCHAR | identifier or source label | Source sex code; unpublished in March analytical layout. |

### Categorical values

| Column | Values in the July 2026 release | Meaning |
|----|----|----|
| `income_band` | `1`, `2`, `3`, `4`, missing | Undocumented codes. Code `4` appears only in contracts signed from 2025 onward. Older releases published text labels instead of codes. |
| `fgts_account_holder` | `S`, `N`, `1`, `0`, missing | FGTS account holder flag, mixing two encodings. Missing in about 94% of rows. |
| `sex` | `M`, `F`, `X`, missing | Source codes. `X` is undocumented. |
| `property_type` | `novo`/`usado` in three capitalizations, missing | New or existing dwelling. |
| `amortization_system` | `price`, `sac`, `sacre` in varying case, missing | Price, SAC, or SACRE amortization. |
| `financing_program` | Program labels | Includes lines such as `Fundo Social` and `Classe Média`. Some labels vary in spelling, such as `Apoio à Produção` and `Apoio à producao`. |

`interest_rate` is in percentage units as published. The source does not
state its periodicity. `household_income` has no stated periodicity
either.

### Subsidy components

The four subsidy columns split the subsidy by funding source and
mechanism.

- `subsidy_fgts_discount` and `subsidy_ogu_discount` are the discounts
  applied to the purchase, funded by the FGTS or by the federal budget
  (OGU).
- `subsidy_fgts_interest` and `subsidy_ogu_interest` are the interest
  subsidies (“equilíbrio”) that lower the financing cost.

In the July 2026 release, the four components sum to `subsidy_total` in
`financing_summary` for every municipality, month, and income band. The
discount components alone do not.

## `financing_summary`

Official totals by municipality, year, month, and income band. These are
the Ministry’s own totals, not sums computed by the package.

| Column | Source header | Type | Unit | Definition |
|:---|:---|:---|:---|:---|
| `reference_date` | `data_referencia` | DATE | calendar date | Reference date reported inside the source; not retrieval or publication date. |
| `code_muni_6` | `cod_ibge` | VARCHAR | identifier or source label | Six-digit IBGE municipality identifier without its check digit. |
| `name_muni` | `txt_municipio` | VARCHAR | identifier or source label | Municipality name as published, including whitespace and capitalization. |
| `state` | `mcmv_fgts_txt_uf` | VARCHAR | identifier or source label | Source state abbreviation. |
| `region` | `txt_regiao` | VARCHAR | identifier or source label | Source Brazilian region label; capitalization is preserved. |
| `contract_year` | `num_ano` | INTEGER | year | Source financing year; missing years are retained. |
| `contract_month` | `num_mes` | INTEGER | month (1-12) | Source financing month; absent in annual summaries. |
| `units_financed` | `qtd_uh_financiadas` | INTEGER | housing units | Number of financed housing units reported in this observation. |
| `amount_financed` | `vlr_financiamento` | DOUBLE | nominal BRL | Financing amount, in nominal BRL. |
| `subsidy_total` | `vlr_subsidio` | DOUBLE | nominal BRL | Official total subsidy in nominal BRL; July reconciles to all four analytical subsidy components. |
| `income_band` | `txt_compatibilidade_faixa_renda` | VARCHAR | identifier or source label | Source income-band label or code; no undocumented code crosswalk is applied. |

In the July 2026 release, the summary and `financing` agree in every
municipality, year, month, and income band: unit counts match exactly
and amounts match within BRL 0.01.

## `subsidized_projects`

One published subsidized-project record. Duplicate rows and missing
operation codes are retained. These projects are funded by the federal
budget (OGU) under modalities such as FAR, Entidades, Rural, and Oferta
Publica.

| Column | Source header | Type | Unit | Definition |
|:---|:---|:---|:---|:---|
| `reference_date` | `data_referencia` | DATE | calendar date | Reference date reported inside the source; not retrieval or publication date. |
| `code_muni_6` | `cod_ibge` | VARCHAR | identifier or source label | Six-digit IBGE municipality identifier without its check digit. |
| `name_muni` | `txt_nome_municipio` | VARCHAR | identifier or source label | Municipality name as published, including whitespace and capitalization. |
| `state` | `txt_sigla_uf` | VARCHAR | identifier or source label | Source state abbreviation. |
| `region` | `txt_regiao` | VARCHAR | identifier or source label | Source Brazilian region label; capitalization is preserved. |
| `contract_date` | `dt_assinatura` | DATE | calendar date | Project contract signature date. |
| `operation_code` | `cod_operacao` | VARCHAR | identifier or source label | Source operation identifier; missing and repeated values are retained. Not a primary key. |
| `project_name` | `txt_nome_empreendimento` | VARCHAR | identifier or source label | Source development name. |
| `financial_agent` | `txt_nome_agente_financeiro` | VARCHAR | identifier or source label | Source financial-agent name. |
| `modality` | `txt_modalidade` | VARCHAR | identifier or source label | Source housing modality label. |
| `project_status` | `txt_situacao_empreendimento` | VARCHAR | identifier or source label | Source project-status label. |
| `units_contracted` | `qtd_uh` | INTEGER | housing units | Reported contracted housing units, including repeated source records. |
| `units_delivered` | `qtd_uh_entregues` | INTEGER | housing units | Reported delivered housing units. |
| `units_outstanding` | `qtd_uh_vigentes` | INTEGER | housing units | Reported active outstanding housing units. |
| `units_cancelled` | `qtd_uh_distratadas` | INTEGER | housing units | Reported cancelled housing units; missing counts are not zero. |
| `amount_contracted` | `val_contratado_total` | DOUBLE | nominal BRL | Total project contract amount, in nominal BRL. |
| `amount_disbursed` | `val_desembolsado` | DOUBLE | nominal BRL | Disbursed project amount, in nominal BRL. |
| `responsible_entity_cnpj` | `txt_cnpj_construtora_entidade` | VARCHAR | identifier or source label | Source CNPJ of construction company or social entity, stored as character. |
| `responsible_entity_name` | `txt_nome_construtora_entidade` | VARCHAR | identifier or source label | Source name of construction company or social entity. |
| `address` | `txt_endereco` | VARCHAR | identifier or source label | Source project address. |
| `postal_code` | `txt_cep` | VARCHAR | identifier or source label | Source postal code (CEP), stored as character. |

Keep these points in mind before aggregating.

- **Duplicates.** The June 2026 release has 3,281 exact duplicate rows.
  Remove them with
  [`distinct()`](https://dplyr.tidyverse.org/reference/distinct.html)
  before counting projects or units.
- **Operation codes.** `operation_code` is missing in 4,608 rows and
  repeats in others, so it is not a primary key.
- **Unit accounting.** `units_contracted` equals
  `units_delivered + units_outstanding + units_cancelled` in every row
  where all four are reported. Six rows lack `units_cancelled`.
- **Labels.** `modality` includes both `Rural` and `RURAL`.

`responsible_entity_cnpj` and `postal_code` are text, which preserves
leading zeros.

## Changes across source releases

The Ministry has changed file layouts between releases without notice.
The package recognizes the layouts below and rejects any other layout.

| Release | Table | Change |
|----|----|----|
| December 2025 | `financing` | 23 columns with birth date and project name; income bands as text labels; Brazilian number format. |
| March 2026 | `financing` | No `sex` column; state header renamed; decimal-point numbers; about 494,000 rows labeled `Fora MCMV/CVA`. |
| July 2026 | `financing` | `sex` returns; birth date and project name removed; income bands become codes `1` to `4`; Brazilian number format. |
| Up to 2025 | `financing_summary` | Annual totals by municipality, without month, region, or income band. |
| July 2026 | `financing_summary` | Monthly totals by municipality and income band; decimal-point numbers. |
| March 2026 | `subsidized_projects` | Decimal-point numbers. |
| June 2026 | `subsidized_projects` | Same headers as March, but Brazilian number format and thousands separators in municipality codes. |

Columns missing from a release appear as `NA` in every row of that
snapshot. In annual summaries, a missing `contract_month` means the
source did not publish monthly detail, not January.

Each release replaces the full history, and releases overlap. They are
published as separate snapshots and should not be appended to each
other.
