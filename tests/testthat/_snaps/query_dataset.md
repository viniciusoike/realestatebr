# query_dataset rejects the former CNO table name

    Code
      query_dataset("cno", table = "works", quiet = TRUE)
    Condition
      Error in `query_dataset()`:
      ! Table "works" is not available for dataset "cno".
      ℹ Available tables: "constructions", "areas", "cnaes", and "responsibilities".

# query_dataset rejects manifest columns outside the registry

    Code
      query_dataset("cno", table = "constructions", quiet = TRUE)
    Condition
      Error in `validate_query_manifest()`:
      ! Manifest schema does not match the package registry for table
        "constructions".

# query_dataset rejects Parquet whose schema differs from registry

    Code
      query_dataset("cno", table = "constructions", quiet = TRUE)
    Condition
      Error in `value[[3L]]()`:
      ! Could not open lazy dataset tables: Parquet schema does not match the
        package registry for table "constructions".

# query_dataset pins an explicit version

    Code
      query_dataset("cno", version = "2025-12-31", quiet = TRUE)
    Condition
      Error in `validate_query_manifest()`:
      ! Requested dataset version "2025-12-31" is not available at this
        manifest.
      ℹ The manifest contains version "2026-01-02".

# query_dataset rejects malformed versions before network access

    Code
      query_dataset("cno", version = "../current", quiet = TRUE)
    Condition
      Error in `validate_query_arguments()`:
      ! `version` must be "latest" or use the YYYY-MM-DD format.

# materialized and queryable access modes are explicit

    Code
      get_dataset("cno", quiet = TRUE)
    Condition
      Error in `get_dataset()`:
      ! Dataset "cno" uses lazy query access.
      ℹ Use `query_dataset("cno")` instead.

---

    Code
      query_dataset("abecip", quiet = TRUE)
    Condition
      Error in `query_dataset()`:
      ! Dataset "abecip" uses materialized access.
      ℹ Use `get_dataset("abecip")` instead.

