# National Registry of Construction Works

Registration, area, economic activity, and responsibility records for
Brazilian construction works.

Retrieve this dataset with
[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md)
using the name `"cno"`.

    cno <- query_dataset("cno")
    cno$works

## Source

Receita Federal do Brasil - Cadastro Nacional de Obras

## Details

- **Source**: Receita Federal do Brasil - Cadastro Nacional de Obras

- **URL**:
  <https://dados.gov.br/dados/conjuntos-dados/cadastro-nacional-de-obras-cno>

- **Geography**: Brazil

- **Frequency**: annual snapshots

- **Coverage**: November 2018-present, including migrated CEI records
  with earlier start dates

- **Access mode**: `query`

- **Tables**: `"works"`, `"areas"`, `"cnaes"`, `"responsibilities"`

Column names are normalized to English, while source labels and
anomalous values are retained without analytical cleaning.

## Table "works" (Construction Works)

One row per CNO registration.

- cno:

  Twelve-digit CNO registration identifier. Stored as character to
  preserve leading zeroes.

- country_code:

  Three-digit country code published by Receita Federal.

- country_name:

  Country name published by Receita Federal.

- start_date:

  Declared start date of the construction work. Historical sentinel
  values are retained.

- responsibility_start_date:

  Start date of the current responsibility period.

- registration_date:

  Date on which the work was registered in CNO.

- linked_cno:

  Linked CNO registration when supplied by Receita Federal.

- postal_code:

  Postal code for works in Brazil. Stored as character.

- responsible_tax_id:

  Fourteen-digit identifier of the responsible legal person. Receita
  Federal suppresses CPF values.

- responsible_role_code:

  Four-digit code for the responsible party's role.

- work_name:

  Name assigned to the construction work, not the responsible party's
  name.

- municipality_tom_code:

  Four-digit Receita Federal TOM municipality code, not an IBGE
  municipality code.

- municipality_name:

  Municipality name published by Receita Federal.

- street_type:

  Street type.

- street_name:

  Street name.

- street_number:

  Street number or other source value such as S/N.

- neighborhood:

  Neighborhood name.

- state:

  State field as published. Usually a two-letter UF abbreviation; source
  anomalies are retained.

- postal_box:

  Postal box for works outside Brazil.

- address_complement:

  Additional address information.

- measurement_unit:

  Unit used to measure the work.

- total_area:

  Total measurement reported for the work, expressed in
  measurement_unit. Source outliers are retained.

- status_code:

  Two-digit CNO status code.

- status_date:

  Date associated with the current status.

- responsible_legal_name:

  Legal name of the responsible legal person when published.

- plus_code:

  Location code published by Receita Federal. Invalid and sentinel
  source values are retained.

## Table "areas" (Construction Areas)

Area records classified by category, destination, structure, and area
type.

- cno:

  CNO registration identifier joining to works.cno.

- work_category:

  Category reported for the work area.

- destination:

  Intended use reported for the work area.

- structure_type:

  Construction structure type.

- area_type:

  Principal or complementary area.

- complementary_area_type:

  Complementary-area classification, when applicable.

- area:

  Reported area in square metres. Source duplicates and outliers are
  retained.

## Table "cnaes" (Economic Activities)

CNAE economic activities associated with each construction work.

- cno:

  CNO registration identifier joining to works.cno.

- cnae:

  Seven-digit CNAE activity code. Stored as character.

- registration_date:

  Date on which the activity was registered.

## Table "responsibilities" (Responsibility Periods)

Responsible-party roles and their periods for each construction work.

- cno:

  CNO registration identifier joining to works.cno.

- start_date:

  Start date of the responsibility period.

- end_date:

  End date of the responsibility period, when applicable.

- registration_date:

  Date on which the responsibility was registered.

- responsible_role_code:

  Four-digit code for the responsible party's role.

- responsible_tax_id:

  Fourteen-digit identifier of the responsible legal person. Receita
  Federal suppresses CPF values.

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
[`fgv_ibre`](https://viniciusoike.github.io/realestatebr/reference/fgv_ibre.md),
[`rppi`](https://viniciusoike.github.io/realestatebr/reference/rppi.md),
[`rppi_bis`](https://viniciusoike.github.io/realestatebr/reference/rppi_bis.md),
[`secovi`](https://viniciusoike.github.io/realestatebr/reference/secovi.md)
