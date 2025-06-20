% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data.R
\docType{data}
\name{main_cities}
\alias{main_cities}
\title{Brazilian city identifier table}
\format{
An object of class \code{tbl_df} (inherits from \code{tbl}, \code{data.frame}) with 72 rows and 3 columns.
}
\source{
\url{https://www.who.int/teams/global-tuberculosis-programme/data}
}
\usage{
main_cities
}
\description{
A subset of \code{dim_city} including the most relevant Brazilian cities.
}
\details{
A data frame with 72 rows and 3 columns:
\describe{
\item{code_muni}{7-digit IBGE code identifying the city.}
\item{name_muni}{Name of the city.}
\item{abbrev_muni}{Year}
}
}
\keyword{datasets}
