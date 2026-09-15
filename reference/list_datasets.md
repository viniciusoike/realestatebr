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
  [`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
  or
  [`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md),
  according to `access_mode`.

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

- access_mode:

  Either `"materialized"` or `"query"`.

- available_tables:

  Comma-separated table names for multi-table datasets.

## See also

[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
and
[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md)
for retrieving data,
[`get_dataset_info()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset_info.md)
for detailed metadata on a single dataset.

## Examples

``` r
list_datasets()
#> Found 9 datasets. Use `get_dataset()` for "materialized" entries and
#> `query_dataset()` for "query" entries.
#> # A tibble: 9 × 11
#>   name         title access_mode available_tables description geography coverage
#>   <chr>        <chr> <chr>       <chr>            <chr>       <chr>     <chr>   
#> 1 abecip       ABEC… materializ… sbpe, units, cgi Housing cr… Brazil    1982-pr…
#> 2 abrainc      ABRA… materializ… indicator, rada… Primary re… Brazil (… 2014-pr…
#> 3 bcb_realest… BCB … materializ… accounting, app… Detailed r… Brazil (… 2001-pr…
#> 4 bcb_series   BCB … materializ… core, primary, … General ec… Brazil    varies …
#> 5 cno          Nati… query       constructions, … Registrati… Brazil    Novembe…
#> 6 fgv_ibre     FGV … materializ… (single table)   Real estat… Brazil    2010-pr…
#> 7 rppi         Braz… materializ… fipezap, ivgr, … Brazilian … Brazil    varies …
#> 8 rppi_bis     BIS … materializ… selected, detai… Internatio… Internat… 1970-pr…
#> 9 secovi       SECO… materializ… condo, rent, la… São Paulo … São Paulo 2004-pr…
#> # ℹ 4 more variables: frequency <chr>, title_pt <chr>, source <chr>, url <chr>

list_datasets(source = "BCB")
#> Warning: No datasets found matching the specified criteria.
#> # A tibble: 0 × 11
#> # ℹ 11 variables: name <chr>, title <chr>, access_mode <chr>,
#> #   available_tables <chr>, description <chr>, geography <chr>, coverage <chr>,
#> #   frequency <chr>, title_pt <chr>, source <chr>, url <chr>
```
