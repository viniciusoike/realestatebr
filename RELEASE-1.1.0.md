# realestatebr 1.1.0 release checklist

This release is additive. It groups the CNO query interface, validated
CNO Parquet snapshots, the IBGE SINAPI and PIM-PF datasets, and
compatible reliability improvements before the planned 2.0.0 schema
migration.

## Scope

Confirm the package version is `1.1.0` at release time.

Keep `date_start`, `date_end`, and `...` accepted by
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md).

Confirm that the CNO interface uses `query_dataset("cno")` and that
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
continues to reject lazy datasets with a clear message.

Validate the CNO snapshot manifest, schema hash, row counts, and source
attribution.

Publish or refresh the immutable CNO Parquet release and its latest
pointer.

Ensure the package registry points to the intended CNO snapshot.

Confirm that `sinapi.rds` and `pim_pf_construction.rds` are published in
the `cache-latest` release.

## Verification

Run focused
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md)
and
[`query_dataset()`](https://viniciusoike.github.io/realestatebr/reference/query_dataset.md)
tests.

Run the complete test suite.

Regenerate documentation with `devtools::document()`.

Run
[`pkgdown::check_pkgdown()`](https://pkgdown.r-lib.org/reference/check_pkgdown.html).

Run `devtools::check()`.

Run `git diff --check` and review the generated NEWS and reference
pages.

Test a remote filtered CNO query against the published Parquet snapshot.

## Release

Change `DESCRIPTION` from `1.0.1.9000` to `1.1.0`.

Finalize the `NEWS.md` entry.

Run the CRAN submission checks and prepare `cran-comments.md`.

Tag the package release as `v1.1.0`.

Create the GitHub release and link the package release to the CNO
snapshot assets.

Bump `DESCRIPTION` to `1.1.0.9000` after release.

## Deferred to 2.0.0

Shared normalized schemas for materialized datasets.

Removal of the compatibility arguments from
[`get_dataset()`](https://viniciusoike.github.io/realestatebr/reference/get_dataset.md).

Migration documentation and explicit 1.x-to-2.0.0 upgrade notes.
