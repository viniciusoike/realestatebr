# CNO snapshot builder

`build_snapshot.R` converts a complete Receita Federal CNO extraction into
four joinable Parquet tables and an immutable manifest. It preserves source
rows and values while normalizing headers, types, and text encoding.

Run the builder from the package root.

```r
source("data-raw/cno/build_snapshot.R")

manifest <- build_cno_snapshot(
  source_dir = "data-raw/backlog/CNO/data-raw",
  version = "2026-09-12"
)
```

The output goes to `data-raw/cno_output/<version>/`. The builder aborts rather
than overwrite an existing snapshot. It validates source headers, declared
totals, the uniqueness and width of `works$cno`, child-table foreign keys, and
source-to-Parquet row counts before publishing the staged directory.
The manifest records each column and type, a schema hash, table keys, row
counts, file sizes, and SHA-256 checksums for both source and Parquet files.

Each logical table is initially stored in one Parquet file. `works` is sorted
by state and CNO, and the child tables are sorted by CNO, which lets DuckDB use
row-group statistics without creating many small state partitions.

The builder needs `cli`, `DBI`, `digest`, DuckDB 1.5.5 or later, `jsonlite`,
and `yaml`. DuckDB's `encodings` extension reads the source's Windows-1252
files. Published Parquet files are UTF-8 and do not require that extension
when users query them.

The manual `Build CNO Snapshot` GitHub Actions workflow accepts the current
source archive URL and a version. Every run uploads a short-lived validation
artifact. With `publish = true`, it also creates an immutable
`cno-<version>` GitHub Release containing the manifest and Parquet files, then
updates `latest.json` in the `cno-latest` release. Reusing a version is allowed
only when the regenerated manifest matches the existing release, apart from
its retrieval timestamp, and all expected assets are present.
