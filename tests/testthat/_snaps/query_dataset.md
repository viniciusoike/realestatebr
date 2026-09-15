# query_dataset rejects Parquet whose schema differs from manifest

    Code
      query_dataset("cno", table = "works", quiet = TRUE)
    Condition
      Error in `value[[3L]]()`:
      ! Could not open lazy dataset tables: Parquet schema does not match the
        manifest for table "works".

# query_dataset pins an explicit version

    Code
      query_dataset("cno", version = "2025-12-31", quiet = TRUE)
    Condition
      Error in `validate_query_manifest()`:
      ! Requested dataset version "2025-12-31" is not available at this
        manifest.
      ℹ The manifest contains version "2026-01-02".

# materialized and queryable access modes are explicit

    Code
      get_dataset("cno", quiet = TRUE)
    Condition
      Error in `get_dataset()`:
      ! Dataset "cno" is not available in this version.
      ℹ The remote data snapshot has not been published.

---

    Code
      query_dataset("abecip", quiet = TRUE)
    Condition
      Error in `query_dataset()`:
      ! Dataset "abecip" uses materialized access.
      ℹ Use `get_dataset("abecip")` instead.

# unpublished query datasets are unavailable without an override

    Code
      query_dataset("cno", quiet = TRUE)
    Condition
      Error in `query_dataset()`:
      ! Dataset "cno" is not available in this version.
      ℹ The remote data snapshot has not been published.

