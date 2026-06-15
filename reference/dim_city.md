# Brazilian city identifier table

A table with official IBGE identifiers for all Brazilian cities.

## Usage

``` r
dim_city
```

## Format

An object of class `tbl_df` (inherits from `tbl`, `data.frame`) with
5570 rows and 9 columns.

## Source

IBGE (Brazilian Institute of Geography and Statistics)

## Details

A `tibble` with 5,570 rows and 9 columns:

- code_muni:

  7-digit IBGE code identifying the city.

- name_muni:

  Name of the city.

- code_state:

  2-digit IBGE code identifying the state.

- abbrev_state:

  Two-letter state abbreviation (e.g. "SP").

- name_state:

  Name of the state.

- code_region:

  1-digit IBGE code identifying the region.

- name_region:

  Name of the region.

- year:

  Reference year of the IBGE territorial division (2020).

- name_simplified:

  Simplified version of the city name for easier subsetting.
