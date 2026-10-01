# PNAD Housing fixtures

Retrieved from the official IBGE Aggregates API v3 on 2026-10-01.

- `6678_brazil_2025.json` contains variable 162 for total households and
  one-resident households. Source request:
  `https://servicodados.ibge.gov.br/api/v3/agregados/6678/periodos/2025/variaveis/162?localidades=N1%5Ball%5D&classificacao=68%5B9902%7C1092%5D`.
- `6788_brazil_2025.json` contains variable 162 for total and one-person
  domestic units, with reference-person sex fixed to total. Source request:
  `https://servicodados.ibge.gov.br/api/v3/agregados/6788/periodos/2025/variaveis/162?localidades=N1%5Ball%5D&classificacao=293%5B100311%5D%7C460%5B45902%7C12076%5D`.
- `6788_brazil_2020_2021.json` preserves all five domestic-unit categories for
  the two years absent from the housing-module tables.
- `6821_geographies_2016_2025.json` preserves the earliest and latest housing
  years for Brazil, Brasília, the São Paulo metropolitan region, and Grande
  Teresina. Its N7 and N14 labels retain IBGE's “até 2020” boundary text.
- `source_audit.csv` records every audited table-period range, variable and
  classification contract, and the number of domains returned at each level.

Both tables report 79,305 thousand total households and 15,633 thousand
one-person households for Brazil in 2025. These are dated fixture values, not
permanent expectations for future live responses.

The live metadata audit confirmed the approved variable, classification,
category, and unit IDs. The four housing-module tables publish 2016-2019 and
2022-2025; table 6788 publishes 2012-2025. Data responses return N1, N2, N3,
N6, N7, and N14 observations. The N7 and N14 locality-list endpoints can return
empty arrays despite published observations, so coverage checks use data rows.
Every audited period returned 1 N1, 5 N2, 27 N3, 27 N6, 20 N7, and 1 N14
domain. The importer pins the audited codes so a same-count substitution fails.

IBGE defines `-` as absolute zero, `0` as a calculated or rounded zero, `X` as
suppressed, `..` as not applicable, and `...` as unavailable. The importer
preserves the raw cell and exposes the interpretation in `value_status`.
