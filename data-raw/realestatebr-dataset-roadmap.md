# `realestatebr` dataset expansion roadmap

The next releases should expand `realestatebr` beyond market and credit indicators into housing, construction, and municipal finance. Ratings use a 1–5 scale, where 5 indicates the greatest importance or complexity.

## Core release

| Dataset | Importance | Import complexity | Maintenance complexity | Scope |
|---|---:|---:|---:|---|
| MCMV | 5 | 2 | 2 | Subsidized housing projects, units, and financing |
| IBGE Census Housing | 5 | 2 | 1 | Housing stock, tenure, vacancies, and dwelling characteristics |
| SINAPI | 5 | 2 | 1 | Construction costs and cost indices |
| PAIC | 4 | 2 | 2 | Construction-industry activity, employment, revenue, costs, and output |
| PNAD Housing | 4.5 | 2 | 2 | Annual housing, tenure, and rent indicators |
| SICONFI IPTU/ITBI | 4 | 2 | 1 | Municipal property-tax and transaction-tax revenue |

## São Paulo special release

Group the city-specific sources into a separate release because they require distinct ingestion and spatial-data workflows.

| Dataset | Importance | Import complexity | Maintenance complexity | Scope |
|---|---:|---:|---:|---|
| ITBI-SP | 5 | 3 | 3 | Property transactions and declared values |
| IPTU-SP | 4.5 | 4 | 3 | Property-level stock, use, area, and age |
| GeoSampa parcels, buildings, and zoning | 4 | 3 | 3 | Parcel geometry, built form, and zoning |

## Deferred sources

- Defer DOI and registry data because access constraints and unstable acquisition workflows would make imports and maintenance costly.
- Deprioritize CBIC because its PDF-based and restricted dissemination makes reliable automated ingestion difficult.
