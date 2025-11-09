# Generic Cache Handler with Fallback

Attempts to load data from user cache with configurable fallback
behavior. Consolidates cache loading logic used across all dataset
functions.

## Usage

``` r
handle_dataset_cache(
  dataset_name,
  table = NULL,
  quiet = FALSE,
  on_miss = c("download", "return_null", "error")
)
```

## Arguments

- dataset_name:

  Character. Name of the dataset (e.g., "abecip").

- table:

  Character or NULL. Specific table to extract from cached data. If
  NULL, returns entire cached dataset.

- quiet:

  Logical. Whether to suppress informational messages.

- on_miss:

  Character. What to do on cache miss:

  - "return_null": Return NULL silently

  - "error": Throw an error

  - "download": Return NULL to trigger download (default)

## Value

The cached data (tibble or list), or NULL on cache miss.

## Details

The function attempts to load data from the user cache directory
(`~/.local/share/realestatebr/` or equivalent). If a table parameter is
provided, it extracts that specific table from the cached dataset.

On cache miss, behavior is controlled by `on_miss`:

- "return_null": Quietly returns NULL (caller handles fallback)

- "error": Throws error (use when cache is required)

- "download": Returns NULL with warning (triggers download in caller)
