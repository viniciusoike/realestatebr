# List Available Datasets

Returns a tibble describing all datasets available in the realestatebr
package. Optionally filter by category, source organisation, or
geographic coverage.

## Usage

``` r
list_datasets(category = NULL, source = NULL, geography = NULL)
```

## Arguments

- category:

  Optional character. Keyword matched against the dataset description
  (e.g., `"indicators"`, `"prices"`, `"credit"`).

- source:

  Optional character. Filter by data source organisation (e.g., `"BCB"`,
  `"FIPE"`, `"ABRAINC"`).

- geography:

  Optional character. Filter by geographic coverage (e.g., `"Brazil"`,
  `"São Paulo"`).

## Value

A tibble with one row per dataset and the following columns:

- name:

  Dataset identifier used with
  [`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md).

- title:

  English dataset name.

- title_pt:

  Portuguese dataset name.

- description:

  Brief description.

- source:

  Data source organisation.

- geography:

  Geographic coverage.

- frequency:

  Update frequency.

- coverage:

  Time period covered.

- available_tables:

  Comma-separated table names for multi-table datasets.

## See also

[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
for retrieving data,
[`get_dataset_info`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
for detailed metadata on a single dataset.

## Examples

``` r
# List all available datasets
datasets <- list_datasets()
#> Found 8 datasets. Use get_dataset(name) to retrieve data.

# Filter by data source
bcb_data <- list_datasets(source = "abecip")
#> Found 1 dataset. Use get_dataset(name) to retrieve data.

# Filter by geography
sao_paulo_data <- list_datasets(geography = "São Paulo")
#> Found 1 dataset. Use get_dataset(name) to retrieve data.
```
