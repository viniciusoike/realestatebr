# MCMV snapshot builder

`build_snapshot.R` converts one release of the Ministério das Cidades MCMV
open data into three Parquet tables and an immutable manifest. It normalizes
headers and types but keeps source rows, labels, duplicates, and missing
values.

Run the builder from the package root. Each input is a CSV, ZIP, or RAR file.
The `layouts` argument defaults to the July 2026 formats; pass it explicitly
for other releases.

```r
source("data-raw/mcmv/build_snapshot.R")

manifest <- build_mcmv_snapshot(
  sources = c(
    financing = "data-raw/backlog/fgts/mcmv_financ_analitico_20260724.csv",
    financing_summary = "data-raw/backlog/fgts/mcmv_financ_sintetico_20260724_v2.csv",
    subsidized_projects = "data-raw/backlog/fgts/mcmv_subsidiado_20260630.csv"
  ),
  version = "2026-07-24"
)
```

`build_initial_snapshot.R` runs this build and checks the row counts,
reconciliation, and project accounting observed for the July 2026 inputs.

## Layouts

The Ministry changes column sets and number formats between releases, and
headers alone do not reveal the number format. Each layout in
`mcmv_layouts()` therefore declares its headers and its format.

| Table | Layouts |
|---|---|
| `financing` | `financing_legacy`, `financing_march`, `financing_july` |
| `financing_summary` | `summary_annual`, `summary_monthly` |
| `subsidized_projects` | `projects_march`, `projects_june` |

The builder reads every column as text, then converts it according to the
layout. It aborts on unexpected headers, on values that fail to parse, and on
timestamps that are not at midnight. A new source release that changes its
format fails loudly; add a layout for it rather than loosening the checks.

## Validation and output

The output goes to `data-raw/mcmv_output/<version>/`. The builder aborts
rather than overwrite an existing snapshot. Before publishing the staged
directory, it checks that row counts and record fingerprints match between the
source and the Parquet files, and that the Parquet schema matches the
registry.

The manifest records the following for each table.

- Source URL, file hashes, layout, and number format.
- Columns absent from the release.
- Row counts, reference dates, and file checksums.
- A profile of missing values, duplicates, and value ranges.

It also records the unit accounting of `subsidized_projects`. For a monthly
summary, it records the reconciliation between `financing` and
`financing_summary`.

`financing` is sorted by state, municipality, and contract date, so DuckDB can
skip row groups when users filter by region.

The builder needs `cli`, `DBI`, `digest`, DuckDB 1.5.5 or later, `jsonlite`,
and `yaml`, plus `bsdtar` for archives.

## Publishing

The manual `Build MCMV Snapshot` GitHub Actions workflow takes one URL and
layout per table, a version, and the dataset license. Every run uploads a
short-lived validation artifact. With `publish = true`, it also:

1. creates an immutable `mcmv-<version>` release with the manifest and
   Parquet files;
2. queries the published files remotely;
3. updates `latest.json` in the `mcmv-v1-latest` release.

Publishing requires a license with an evidence URL.
