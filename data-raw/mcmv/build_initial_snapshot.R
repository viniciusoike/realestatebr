# Build and verify the inspected July/June inputs, not future release constraints ----
source("data-raw/mcmv/build_snapshot.R")

sources <- c(
  financing = "data-raw/backlog/fgts/mcmv_financ_analitico_20260724.csv",
  financing_summary = "data-raw/backlog/fgts/mcmv_financ_sintetico_20260724_v2.csv",
  subsidized_projects = "data-raw/backlog/fgts/mcmv_subsidiado_20260630.csv"
)
manifest_path <- build_mcmv_snapshot(sources, version = "2026-07-24")
manifest <- jsonlite::read_json(manifest_path, simplifyVector = FALSE)
observed <- vapply(manifest$tables, `[[`, numeric(1), "rows")
expected <- c(financing = 7849882, financing_summary = 795684, subsidized_projects = 26111)
if (!identical(observed, expected)) cli::cli_abort("Initial input row baseline changed.")
r <- manifest$validation$reconciliation
if (r$status != "compared" || r$group_count != 795684 ||
  any(unlist(r[c("unmatched_groups", "unit_mismatches", "amount_mismatches", "subsidy_mismatches")]) != 0)) {
  cli::cli_abort("Initial financing reconciliation baseline changed.")
}
p <- manifest$validation$project_accounting
if (manifest$tables$subsidized_projects$profile$exact_duplicate_rows != 3281 ||
  p$missing_operation_codes != 4608 || p$complete_rows != 26105 ||
  p$missing_cancellation_counts != 6 || p$unit_identity_mismatches != 0) {
  cli::cli_abort("Initial project baseline changed.")
}
cli::cli_inform("All inspected-input baselines reproduced.")
