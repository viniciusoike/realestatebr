# CNO snapshot builder

`build_snapshot.R` converts a complete Receita Federal CNO extraction into
four joinable Parquet tables and an immutable manifest. It normalizes headers,
types, text encoding, and surrounding whitespace, and fixes mechanical source
defects:

- `1900-01-01` sentinel dates become `NA` in every date column.
- `plus_code` values that are not valid Plus Codes become `NA`; valid codes
  are stored in upper case.
- Exact duplicate rows in `areas` are dropped. Summing areas with the
  duplicates never reproduces `constructions.total_area`.
- `constructions.code_muni` adds the seven-digit IBGE code from the Receita
  Federal TOM-to-IBGE table
  (<https://www.gov.br/receitafederal/dados/municipios.csv>).

The manifest counts each fix per table, records source and published row
counts, and stores the crosswalk checksum. The build aborts when more than
0.1% of TOM codes have no IBGE match. Valid but anomalous values, such as area
outliers and unusual `state` labels, are kept.

Run the builder from the package root.

```r
source("data-raw/cno/build_snapshot.R")

manifest <- build_cno_snapshot(
  source_dir = "data-raw/backlog/CNO/data-raw",
  crosswalk_path = "data-raw/backlog/CNO/crosswalk/municipios.csv",
  version = "2026-09-12"
)
```

The output goes to `data-raw/cno_output/<version>/`. The builder aborts rather
than overwrite an existing snapshot. It validates source headers, declared
totals, the uniqueness and width of `constructions$cno`, child-table foreign keys, and
source-to-Parquet row counts before publishing the staged directory.
The manifest records each column and type, a schema hash, table keys, row
counts, file sizes, and SHA-256 checksums for both source and Parquet files.

Each logical table is initially stored in one Parquet file. `constructions` is sorted
by state and CNO, and the child tables are sorted by CNO, which lets DuckDB use
row-group statistics without creating many small state partitions.

The builder needs `cli`, `DBI`, `digest`, DuckDB 1.5.5 or later, `jsonlite`,
and `yaml`. The builder converts Windows-1252 inputs to temporary UTF-8
files in chunks before DuckDB reads them. This avoids requiring the
`encodings` extension, which is unavailable for the Windows MinGW platform.
Temporary files are removed when the build finishes or fails; the manifest
records checksums of the original inputs.

The manual `Build CNO Snapshot` GitHub Actions workflow accepts the current
source archive URL and a version. Every run uploads a short-lived validation
artifact. With `publish = true`, it also creates an immutable
`cno-<version>` GitHub Release containing the manifest and Parquet files, then
updates `latest.json` in the `cno-v3-latest` release. Reusing a version is allowed
only when the regenerated manifest matches the existing release, apart from
its retrieval timestamp, and all expected assets are present.
