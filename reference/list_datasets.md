# List Available Datasets

Returns a tibble describing all datasets available in the realestatebr
package. Optionally filter by category, source organization, or
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

  Optional character. Filter by data source organization (e.g., `"BCB"`,
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

  Data source organization.

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
list_datasets()
#> Found 8 datasets. Use get_dataset(name) to retrieve data.
#> # A tibble: 8 × 10
#>   name  title available_tables description geography coverage frequency title_pt
#>   <chr> <chr> <chr>            <chr>       <chr>     <chr>    <chr>     <chr>   
#> 1 abec… ABEC… sbpe, units, cgi Housing cr… Brazil    1982-pr… monthly   Indicad…
#> 2 abra… ABRA… indicator, rada… Primary re… Brazil (… 2014-pr… quarterly Indicad…
#> 3 bcb_… BCB … accounting, app… Comprehens… Brazil (… 2001-pr… monthly   Dados d…
#> 4 bcb_… BCB … core, primary, … General ec… Brazil    varies … varies (… Séries …
#> 5 fgv_… FGV … (single table)   Real estat… Brazil    2010-pr… monthly   Indicad…
#> 6 rppi  Braz… fipezap, ivgr, … Comprehens… Brazil    varies … monthly   Índices…
#> 7 rppi… BIS … selected, detai… Internatio… Internat… 1970-pr… quarterly Índices…
#> 8 seco… SECO… condo, rent, la… São Paulo … São Paulo 2004-pr… monthly   Dados d…
#> # ℹ 2 more variables: source <chr>, url <chr>

list_datasets(source = "BCB")
#> Warning: No datasets found matching the specified criteria.
#> # A tibble: 0 × 10
#> # ℹ 10 variables: name <chr>, title <chr>, available_tables <chr>,
#> #   description <chr>, geography <chr>, coverage <chr>, frequency <chr>,
#> #   title_pt <chr>, source <chr>, url <chr>
```
