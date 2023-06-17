#' Get FGV Confidence Indicators
#'
#' Download and clean construction confidence indicators estimated and released
#' by the Getúlio Vargas Foundation (FGV).
#'
#' @details
#' Available category options are `nuci`, `ie_cst`, `ic_cst`, and `isa_cst`.
#'
#'
#'
#' @param category Defaults to `'all'`. Check details for more information.
#' @inheritParams get_secovi
#'
#' @return A `tibble` containing all construction confidence indicator series from FGV.
#' @export
get_fgv_indicators <- function(category = "all", cached = FALSE) {

  # Check if category argument is valid

  # Swap vector for categories
  vl_category <- c(
    "used_capacity" = "nuci",
    "expectations" = "ie_cst",
    "confidence" = "ic_cst",
    "current" = "isa_cst"
    )

  # Group all valid category options into a single vector
  cat_options <- c("all", names(vl_category))
  # Collapse into a single string for error output message
  error_msg <- paste(cat_options, collapse = ", ")
  # Check if 'category' is valid
  if (!any(category %in% cat_options)) {
    stop(glue::glue("Category must be one of: {cat_options}."))
  }
  # Swap category with vars
  vars <- ifelse(category == "all", vl_category, vl_category[category])

  if (cached) {

    df <- import_cached("fgv_indicators")
    df <- dplyr::filter(df, name_simplified %in% vars)

  } else {

    df <- dplyr::filter(fgv_data, name_simplified %in% vars)

  }

  df <- stats::na.omit(df)

  return(df)

}
