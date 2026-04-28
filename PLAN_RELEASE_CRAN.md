# realestatebr — CRAN v1.0 Release Plan

## Context

The package is ~95% CRAN-ready: clean DESCRIPTION, lean NAMESPACE (13 exports — primarily `list_datasets()`, `get_dataset()`, `get_dataset_info()` plus cache utilities), tests guarded with `skip_on_cran()` / `skip_if_offline()`, examples wrapped in `\dontrun{}`, no oversized data files. Current `R CMD check`: **0 ERROR / 0 WARNING / 1 NOTE** (ignoring local `pdflatex` issue).

What's blocking a clean v1.0 submission:

1. **Inventory bloat.** Four datasets in the registry don't belong in v1.0 — `nre_ire` (manual, 6mo stale, niche stock-price index), `itbi_summary` (registry status: `hidden`, never finished), the `itbi`/`itbi_bhe` internal helpers (Belo Horizonte only, marked Phase 4 future work), and `property_records` (source no longer available — discovered during further investigation). They aren't wired into the pipeline reliably and shipping them invites CRAN reviewer questions about "what does this function actually do."
2. **One fragile-but-keeping dataset needs verification.** `cbic` cache is 75 days stale. We're keeping it — but it must be confirmed working before submission, not after.
3. **Dev-note clutter.** `claude/` directory holds ~15 obsolete v0.3–0.4 phase summaries, fix logs, and workflow docs. Already in `.Rbuildignore` so doesn't affect the build, but pollutes the repo. Plus stray files in root (`view_dados_abertos_ogu_*.csv`, `mcmv.R`, `fgv_data.rds`) and unused R/ files (`translation.R` likely dead, `utils.R` of unclear purpose).
4. **CRAN-comments has a TODO.** `cran-comments.md` line 33 still says `[Add rhub::check_for_cran() results before submission]`.

**Outcome wanted:** clean v1.0 submission within ~2 weeks, first-time CRAN. Conservative scope where every shipped dataset is verifiably functional. Deferred datasets stay in git history, not in the v1.0 build.

---

## Final v1.0 dataset roster

**Ship (9 registry entries):**
- `abecip`, `abrainc`, `bcb_realestate`, `bcb_series`, `secovi` — GREEN, recent caches, tested
- `rppi`, `rppi_bis` — GREEN/YELLOW, recent migration to verify
- `fgv_ibre` — manual-update, document the workflow
- `cbic` — refresh cache, verify scrape, add a smoke test

**Drop (deleted from v1.0):**
- `nre_ire` — registry entry, `R/get_nre_ire.R`, `data-raw/process_nre_ire.R`, `data-raw/nre_ire.xlsx`, any cache assets, any test references
- `itbi_summary` — registry entry, `R/get_itbi.R`, `R/get_itbi_bhe.R`, references in `get-dataset.R` switch logic
- `property_records` — registry entry, `R/get_property_records.R`, any cache assets, test references. **Source no longer available** (discovered during further investigation); discard the uncommitted changes in `R/get_property_records.R` rather than committing them

---

## Phase 1 — Repo cleanup (low-risk, ~half day)

Goal: shrink the surface to the actual v1.0 codebase before touching anything substantive.

### 1.1 Delete obsolete dev notes

```
rm -rf claude/                    # ~15 phase/fix/workflow notes from v0.3–0.4
                                  # except: keep claude/coding_guidelines.md
                                  # → mv claude/coding_guidelines.md inst/coding_guidelines.md.bak
                                  # actually: just keep CLAUDE.md at root; coding_guidelines content
                                  # is reflected there. Confirm before deleting.
```

Also remove:
- `backup/` (root) — old code snapshots
- `old/` (root) — same
- `data-raw/draft/` — work-in-progress files
- `data-raw/fgv_backup/` — superseded by fgv_data.rds + fgv_clean.R
- `data-raw/archive/` — keep IF it has historical raw inputs we'd need to regenerate; otherwise delete
- `.Rhistory`, `.DS_Store` files — stale local state

### 1.2 Delete stray root files

- `view_dados_abertos_ogu_202603201556.csv` (5.4 MB orphan, not referenced anywhere)
- `data-raw/mcmv.R` (uncommitted, untracked — confirm not needed)
- `data-raw/fgv_data.rds` (untracked — verify this isn't the canonical input for fgv_ibre; if it is, decide whether to commit or replace with the CSV path)

### 1.3 Audit and possibly remove dead R/ files

Read and confirm before deleting:
- `R/translation.R` — if no exported or internal caller uses it, delete
- `R/utils.R` — verify which helpers are used; remove unused ones
- `R/utils-globals.R` — check for stale `globalVariables()` calls referencing deleted code

Don't touch `R/utils-encoding.R`, `R/helpers-dataset.R`, `R/helpers-download.R`, `R/rppi-helpers.R` — these are actively used.

### 1.4 Tighten `.Rbuildignore` and `.gitignore`

Confirm both ignore:
- `.claude/`, `claude/` (already)
- `_targets/`, `logs/`, `data-raw/cache_output/`
- `*.Rcheck/`, `..Rcheck/`
- `cran-comments.md`, `CLAUDE.md`

Verify nothing slipped in: `R CMD build .` should produce a tarball under ~1 MB.

---

## Phase 2 — Drop deferred datasets (~half day)

### 2.1 Files to delete

- `R/get_nre_ire.R`
- `R/get_itbi.R`
- `R/get_itbi_bhe.R`
- `R/get_property_records.R` (discard uncommitted changes — `git checkout -- R/get_property_records.R` first, then `git rm`)
- `data-raw/process_nre_ire.R`
- `data-raw/nre_ire.xlsx`
- Any `nre_ire.*` files in `data-raw/cache_output/`
- Any `itbi*` files in `data-raw/cache_output/`
- Any `property_records.*` files in `data-raw/cache_output/`

### 2.2 Files to edit

**`inst/extdata/datasets.yaml`** — remove `nre_ire:`, `itbi_summary:`, and `property_records:` blocks.

**`R/get-dataset.R`** — remove any switch branches or special-case logic referencing nre_ire / itbi / property_records. Search for `nre_ire`, `itbi`, `fetch_nre`, `fetch_itbi`, `fetch_registro`, `property_records`.

**`_targets.R`** — remove `property_records` from the monthly group (the targets pipeline currently includes it). Confirm nre_ire and itbi aren't in any target group (per Explore findings, they aren't). Grep to be sure.

**`tests/testthat/`** — remove any test cases referencing `get_dataset("nre_ire")`, `get_dataset("property_records")`, or itbi datasets.

**`R/realestatebr-package.R` / `R/utils-globals.R`** — drop any `globalVariables()` declarations that referenced deleted code paths.

**`NEWS.md`** — add v0.7.0 / v1.0.0 entry noting removed datasets:

```
# realestatebr 1.0.0

## Breaking changes

* `nre_ire`, `itbi_summary`, and the internal ITBI helpers have been removed
  from this release. They are deferred to a future version pending automation
  and reliability improvements.
* `property_records` has been removed because the upstream source is no longer
  available.
```

### 2.3 Verify after deletion

```r
devtools::document()
devtools::load_all()
list_datasets()                    # 9 datasets, no nre_ire / itbi_summary / property_records
devtools::check()                  # 0 errors, 0 warnings, ≤1 NOTE
```

---

## Phase 3 — Verify the fragile keepers (~1-2 days)

With `property_records` removed, this phase shrinks substantially. Only `cbic` is genuinely risky now.

### 3.1 `cbic`

1. Run fresh fetch:
   ```r
   get_dataset("cbic", source = "fresh")
   ```
   For each of the 5 cement tables.
2. Decision rule:
   - **Quick fix** (≤1 day) → fix it, refresh cache
   - **Hard fix** (>1 day) → drop from v1.0 and add to deferred list. Don't burn the timeline on this.
3. Refresh cache, upload to release.
4. Add cache-only smoke test in `tests/testthat/test-integration-get_dataset.R`.

### 3.2 `fgv_ibre`

1. Confirm the manual-update workflow: `data-raw/fgv_clean.R` reads `data-raw/xgdvConsulta.csv` (or whatever the canonical input is now — verify after Phase 1.2). Document this in a comment block at the top of `fgv_clean.R`.
2. Add a one-liner to `inst/extdata/datasets.yaml` `update_notes` field that points to the manual workflow.
3. No automation, but document clearly.

### 3.3 `rppi_bis`

1. Run fresh fetch end-to-end (post-migration verification).
2. Confirm BIS ZIP/CSV pipeline works.
3. Cache-only smoke test exists or add one.

---

## Phase 4 — CRAN-readiness fixes (~1 day)

### 4.1 Fix local pdflatex

Install TinyTeX:
```r
tinytex::install_tinytex()
```
Re-run `R CMD check` and confirm PDF builds.

### 4.2 Run pre-submission checks

```r
# Reverse-dependency check is N/A (new package)
devtools::check(cran = TRUE)        # local
devtools::check_win_devel()         # win-builder, R-devel
devtools::check_win_release()       # win-builder, R-release
rhub::rhub_check()                  # rhub v2; pick linux + macos + windows
```

Wait for results (24-48 hours typical). Address any new NOTEs.

### 4.3 Update `cran-comments.md`

Replace line 33 placeholder with actual results:

```
## Test Platforms

- macOS (local): 0 errors, 0 warnings, 0 notes
- win-builder R-devel: 0 errors, 0 warnings, X notes
- win-builder R-release: 0 errors, 0 warnings, X notes
- R-hub linux/macos/windows: 0 errors, 0 warnings, X notes
```

### 4.4 Bump version and finalize NEWS.md

In `DESCRIPTION`: `Version: 1.0.0`.
In `NEWS.md`: ensure top section describes v1.0 changes — initial CRAN release, breaking changes (deferred datasets), and the 10 shipped datasets.

### 4.5 Vignettes

Resolve uncommitted changes in `vignettes/getting-started.Rmd`. Both vignettes already use `eval = FALSE` per `cran-comments.md`. Verify:
- No examples reference `nre_ire`, `itbi_summary`, `property_records`, or the deprecated `get_*_indicators()` functions.
- The dataset list in the vignette matches `list_datasets()` output (9 entries).

---

## Phase 5 — Submit (~30 min, then 1-3 weeks waiting)

```r
devtools::submit_cran()
```

Or manually upload to https://cran.r-project.org/submit.html.

After auto-acknowledgment email:
1. Tag the release: `git tag v1.0.0 && git push --tags`
2. Wait for human review.
3. Address reviewer feedback if any. Common asks: tighten Description, add `\value` tags everywhere, replace `print()`/`cat()` with `message()`/`cli::cli_inform()`.

---

## Critical files that will be modified

**Deletions:**
- `R/get_nre_ire.R`, `R/get_itbi.R`, `R/get_itbi_bhe.R`, `R/get_property_records.R`
- `claude/` (whole directory, after extracting `coding_guidelines.md` if useful)
- `backup/`, `old/`, `data-raw/draft/`, `data-raw/fgv_backup/`
- `view_dados_abertos_ogu_202603201556.csv`, `data-raw/mcmv.R` (after confirmation), various stray files
- Possibly `R/translation.R`, possibly unused parts of `R/utils.R`

**Edits:**
- `inst/extdata/datasets.yaml` — remove nre_ire, itbi_summary, and property_records blocks
- `R/get-dataset.R` — strip nre_ire / itbi / property_records switch branches
- `_targets.R` — remove `property_records` target group entry
- `tests/testthat/test-integration-get_dataset.R` — remove deferred dataset tests, add smoke test for cbic
- `DESCRIPTION` — bump to 1.0.0
- `NEWS.md` — add 1.0.0 entry (note property_records source unavailable)
- `cran-comments.md` — fill in pre-submission test results
- `vignettes/getting-started.Rmd` — sync with new 9-dataset list
- `R/utils-globals.R` — drop dead `globalVariables()` entries

**Possibly modified during Phase 3 fixes:**
- `R/get_cbic.R` — only if scrape needs repair
- Cache files in `data-raw/cache_output/` — refresh and re-upload

---

## Reused infrastructure (don't reinvent)

- `inst/extdata/datasets.yaml` — registry is source of truth; removing entries here propagates via `load_dataset_registry()` in `R/list-datasets.R`
- `R/helpers-dataset.R` — already provides `validate_table_param()` and other helpers; new tests should use them
- `R/cache-user.R` / `R/cache-github.R` — three-tier caching is in place; smoke tests should call `get_dataset(..., source = "cache")` to exercise it
- `_targets.R` — pipeline is fully wired; just verify the deferred datasets aren't included
- `tests/testthat/test-integration-get_dataset.R` — extend, don't replace

---

## Verification checklist (end-to-end)

Run before submission:

```r
# 1. Clean check
devtools::clean_dll()
devtools::document()
devtools::check(cran = TRUE)
# expected: 0 errors, 0 warnings, ≤1 note (about new submission)

# 2. Tests pass
devtools::test()
# expected: 0 failures, all skips appropriate

# 3. Build tarball under 5 MB
devtools::build()
ls -lh ../realestatebr_1.0.0.tar.gz

# 4. Roster matches
devtools::load_all()
list_datasets()  # exactly 9 datasets visible

# 5. Each dataset loads from cache
for (d in list_datasets()$name) {
  message("Testing: ", d)
  result <- tryCatch(
    get_dataset(d, source = "cache"),
    error = function(e) e
  )
  stopifnot(!inherits(result, "error"))
}

# 6. pkgdown site rebuilds without errors
pkgdown::build_site()
```

---

## Risk register

| Risk | Likelihood | Mitigation |
|---|---|---|
| `cbic` scrape currently broken (75d stale → may have rotted) | Medium | Phase 3.1 verifies first; drop to v1.1 if >1 day to fix |
| CRAN reviewer requests Description rewrite | Medium | Pre-emptively expand Description to 3-4 sentences with concrete data sources before submission |
| win-builder reveals platform-specific encoding issues with Portuguese strings | Low-medium | `R/utils-encoding.R` exists; if issues, mark vignette files as UTF-8 explicitly |
| First-time submission policy questions (auto-download caching, internet usage) | Medium | `cran-comments.md` already explains caching & vignette eval=FALSE; expand if needed |

---

## What this plan deliberately does NOT do

- **Strip docs from the 11 internal `get_*` functions.** CLAUDE.md flags this as a goal but it's not a CRAN blocker. Defer to v1.1.
- **Consolidate download/cache logic further** (Phase 3 of internal cleanup). Already done in v0.6.0; further work is post-CRAN.
- **DuckDB / large-data Phase 4 work.** Out of scope.
- **Refactor `get_cbic.R`** (1,723-line monster). Verify it works; refactor in v1.1.
- **Add new datasets.** Lock the roster.
