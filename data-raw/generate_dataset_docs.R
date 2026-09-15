# Generate dataset help topics from the registry ----
#
# Reads inst/extdata/datasets.yaml and writes one R/data-<name>.R file per
# dataset containing a roxygen2 help topic (e.g. ?abecip). The registry is
# the single source of truth for dataset metadata and column descriptions.
#
# Re-run this script after editing the registry, then run
# devtools::document().

library(yaml)

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# Helpers ------------------------------------------------------------------

escape_rd <- function(x) {
  y <- gsub("%", "\\\\%", x)
  return(y)
}

# Wrap text as roxygen comment lines, breaking at ~76 characters
roxy_wrap <- function(text, prefix = "#' ") {
  wrapped <- strwrap(text, width = 76)
  return(paste0(prefix, wrapped))
}

# Build a \describe block from a named list of column descriptions
build_describe <- function(columns) {
  items <- vapply(
    names(columns),
    function(col) {
      desc <- escape_rd(columns[[col]])
      sprintf("#'   \\item{%s}{%s}", col, desc)
    },
    character(1)
  )
  block <- c("#' \\describe{", items, "#' }")
  return(block)
}

# Build the @section block for a single table
build_table_section <- function(key, category, default_table = NULL) {
  title <- sprintf(
    "#' @section Table \"%s\" (%s):",
    key,
    escape_rd(category$name)
  )
  lines <- title
  desc <- escape_rd(category$description)
  if (!is.null(default_table) && identical(key, default_table)) {
    desc <- paste0(desc, ". This is the default table")
  }
  lines <- c(lines, roxy_wrap(paste0(desc, ".")))
  if (!is.null(category$coverage)) {
    lines <- c(lines, sprintf("#' Coverage: %s.", category$coverage))
  }
  lines <- c(lines, "#'")
  if (!is.null(category$columns)) {
    lines <- c(lines, build_describe(category$columns))
  }
  if (!is.null(category$column_notes)) {
    lines <- c(lines, "#'", roxy_wrap(escape_rd(category$column_notes)))
  }
  return(lines)
}

# Topic builder -------------------------------------------------------------

build_topic <- function(key, ds) {
  lines <- character(0)
  add <- function(...) lines <<- c(lines, ...)
  access_mode <- ds$access_mode %||% "materialized"
  access_function <- if (access_mode == "query") {
    "query_dataset"
  } else {
    "get_dataset"
  }

  # Title and description
  add(sprintf("#' %s", escape_rd(ds$name)))
  add("#'")
  add("#' @description")
  add(roxy_wrap(paste0(escape_rd(ds$description), ".")))
  add("#'")
  if (identical(ds$status, "hidden")) {
    add("#' This dataset is under development and is not currently available.")
  } else {
    add(sprintf(
      "#' Retrieve this dataset with [%s()] using the name `\"%s\"`.",
      access_function,
      key
    ))
  }

  tables <- names(ds$categories)
  default_table <- ds$default_table
  if (is.null(default_table) && length(tables) > 0) {
    default_table <- tables[1]
  }

  if (!identical(ds$status, "hidden")) {
    add("#'")
    add("#' ```r")
    add(sprintf("#' %s <- %s(\"%s\")", key, access_function, key))
    if (access_mode == "query") {
      add(sprintf("#' %s$%s", key, default_table))
    } else if (length(tables) > 1) {
      other <- setdiff(tables, default_table)[1]
      add(sprintf(
        "#' %s_%s <- get_dataset(\"%s\", table = \"%s\")",
        key,
        other,
        key,
        other
      ))
    }
    add("#' ```")
  }

  # Details: dataset-level metadata
  add("#'")
  add("#' @details")
  add(sprintf("#' * **Source**: %s", escape_rd(ds$source)))
  if (!is.null(ds$url) && !identical(ds$url, "varies by index")) {
    add(sprintf("#' * **URL**: <%s>", ds$url))
  }
  add(sprintf("#' * **Geography**: %s", escape_rd(ds$geography)))
  add(sprintf("#' * **Frequency**: %s", escape_rd(ds$frequency)))
  add(sprintf("#' * **Coverage**: %s", escape_rd(ds$coverage)))
  add(sprintf("#' * **Access mode**: `%s`", access_mode))
  if (length(tables) > 0) {
    tables_text <- paste0("`\"", tables, "\"`", collapse = ", ")
    if (access_mode == "query") {
      add(sprintf("#' * **Tables**: %s", tables_text))
    } else {
      add(sprintf(
        "#' * **Tables**: %s (default: `\"%s\"`)",
        tables_text,
        default_table
      ))
    }
  }
  if (!is.null(ds$translation_notes)) {
    notes <- escape_rd(ds$translation_notes)
    if (!grepl("\\.$", notes)) {
      notes <- paste0(notes, ".")
    }
    add("#'")
    add(roxy_wrap(notes))
  }

  # Column documentation
  if (!is.null(ds$columns)) {
    # Single shared structure across all tables
    add("#'")
    add("#' @section Columns:")
    if (length(tables) > 1) {
      add(roxy_wrap(paste(
        "All tables share the structure below; the `table` argument",
        "filters which series are returned."
      )))
      add("#'")
    }
    add(build_describe(ds$columns))
  } else {
    # Per-table structures
    for (tbl in tables) {
      category <- ds$categories[[tbl]]
      if (is.null(category$columns)) {
        next
      }
      add("#'")
      section_default <- if (access_mode == "query") NULL else default_table
      add(build_table_section(tbl, category, section_default))
    }
  }

  # Footer
  add("#'")
  add(sprintf("#' @source %s", escape_rd(ds$source)))
  add(
    "#' @seealso [get_dataset()], [query_dataset()], [list_datasets()], [get_dataset_info()]"
  )
  add("#' @family datasets")
  if (identical(ds$status, "hidden")) {
    add("#' @keywords internal")
  } else {
    add("#' @keywords datasets")
  }
  add(sprintf("#' @name %s", key))
  add("NULL")
  return(lines)
}

# Generate files -------------------------------------------------------------

# Read with explicit UTF-8 to handle non-ASCII chars (as in
# load_dataset_registry())
raw_text <- readLines(
  "inst/extdata/datasets.yaml",
  encoding = "UTF-8",
  warn = FALSE
)
registry <- yaml::yaml.load(paste(raw_text, collapse = "\n"))

for (key in names(registry$datasets)) {
  ds <- registry$datasets[[key]]
  topic <- build_topic(key, ds)
  header <- c(
    sprintf(
      "# Generated by data-raw/generate_dataset_docs.R from %s",
      "inst/extdata/datasets.yaml"
    ),
    "# Do not edit by hand; edit the registry and re-run the generator.",
    ""
  )
  path <- file.path("R", paste0("data-", key, ".R"))
  con <- file(path, open = "w", encoding = "UTF-8")
  writeLines(c(header, topic), con)
  close(con)
  message("Wrote ", path)
}
