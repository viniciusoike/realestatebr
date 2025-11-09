# List Available Datasets

Returns information about all available datasets in the realestatebr
package. This provides a unified interface to discover all data sources
and their characteristics.

## Usage

``` r
list_datasets(
  category = NULL,
  source = NULL,
  geography = NULL,
  include_hidden = FALSE
)
```

## Arguments

- category:

  Optional. Filter datasets by category. Common categories include:
  "indicators", "prices", "credit", "stocks". Leave NULL to see all
  datasets.

- source:

  Optional. Filter by data source (e.g., "BCB", "FIPE", "ABRAINC").

- geography:

  Optional. Filter by geographic coverage (e.g., "Brazil", "São Paulo").

- include_hidden:

  Logical. If TRUE, includes datasets with status="hidden". Default is
  FALSE to show only available datasets.

## Value

A tibble with columns:

- name:

  Dataset identifier for use with get_dataset()

- title:

  Human-readable name in English

- title_pt:

  Human-readable name in Portuguese

- description:

  Brief description of the dataset

- source:

  Data source organization

- geography:

  Geographic coverage

- frequency:

  Update frequency

- coverage:

  Time period coverage

- categories:

  Number of categories/subtables

- available_tables:

  Names of available tables (for multi-table datasets)

- data_type:

  Type of data structure (tibble/list)

- legacy_function:

  Internal function name (for reference only)

## See also

[`get_dataset`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
for retrieving the actual data

## Examples

``` r
if (FALSE) { # \dontrun{
# List all available datasets
datasets <- list_datasets()

# Filter by data source
bcb_data <- list_datasets(source = "BCB")

# Filter by geography
sao_paulo_data <- list_datasets(geography = "São Paulo")

# View available tables for multi-table datasets
View(list_datasets()$available_tables)

# Get specific table from multi-table dataset
abecip_sbpe <- get_dataset("abecip", table = "sbpe")
} # }
```
