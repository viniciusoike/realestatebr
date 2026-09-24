# realestatebr 1.1.0 release checklist

This release is additive. It groups the CNO query interface, validated CNO
Parquet snapshots, the IBGE SINAPI and PIM-PF datasets, and compatible
reliability improvements before the planned 2.0.0 schema migration.

## Scope

- [x] Confirm the package version is `1.1.0` at release time.
- [x] Keep `date_start`, `date_end`, and `...` accepted by `get_dataset()`.
- [x] Confirm that the CNO interface uses `query_dataset("cno")` and that
      `get_dataset()` continues to reject lazy datasets with a clear message.
- [x] Validate the CNO snapshot manifest, schema hash, row counts, and source
      attribution.
- [x] Publish or refresh the immutable CNO Parquet release and its latest
      pointer. Published as `cno-2026-09-24`, with `cno-v2-latest` pointing
      to it.
- [x] Ensure the package registry points to the intended CNO snapshot.
- [x] Confirm that `sinapi.rds` and `pim_pf_construction.rds` are published
      in the `cache-latest` release.

## Verification

- [x] Run focused `get_dataset()` and `query_dataset()` tests.
- [x] Run the complete test suite.
- [x] Regenerate documentation with `devtools::document()`.
- [x] Run `pkgdown::check_pkgdown()`.
- [x] Run `devtools::check()`.
- [x] Run `git diff --check` and review the generated NEWS and reference pages.
- [x] Test a remote filtered CNO query against the published Parquet snapshot.

## Release

- [x] Change `DESCRIPTION` from `1.0.1.9000` to `1.1.0`.
- [x] Finalize the `NEWS.md` entry.
- [x] Run the CRAN submission checks and prepare `cran-comments.md`.
- [ ] Tag the package release as `v1.1.0`.
- [ ] Create the GitHub release and link the package release to the CNO
      snapshot assets.
- [ ] Bump `DESCRIPTION` to `1.1.0.9000` after release.

## Deferred to 2.0.0

- [ ] Shared normalized schemas for materialized datasets.
- [ ] Removal of the compatibility arguments from `get_dataset()`.
- [ ] Migration documentation and explicit 1.x-to-2.0.0 upgrade notes.
