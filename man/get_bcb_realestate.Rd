% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_bcb_realestate.R
\name{get_bcb_realestate}
\alias{get_bcb_realestate}
\title{Import Real Estate data from the Brazilian Central Bank}
\source{
\url{https://dadosabertos.bcb.gov.br/dataset/informacoes-do-mercado-imobiliario}
}
\usage{
get_bcb_realestate(category = "all", cached = FALSE)
}
\arguments{
\item{category}{One of \code{'accounting'}, \code{'application'}, \code{'indices'},
\code{'sources'}, \code{'units'}, or \code{'all'} (default).}

\item{cached}{If \code{TRUE} downloads the cached data from the GitHub repository.
This is a faster option but not recommended for daily data.}
}
\value{
If \code{category = 'all'} returns a \code{tibble} with 13 columns where:
\itemize{
\item \code{series_info}: the full name identifying each series.
\item \code{category}: category of the series (first element of \code{series_info}).
\item \code{type}: subcategory of the series (second element of \code{series_info}).
\item \code{v1} to \code{v5}: elements of \code{series_info}.
\item \code{value}: numeric value of the series.
\item \code{abbrev_state}: two letter state abbreviation.
}
}
\description{
Imports and cleans real estate data published monthly by the Brazilian Central
Bank. Includes credit sources, credit applications, credit operations, financed
units, real estate indices.
}
\details{
If \code{category = 'all'} a tidy long \code{tibble} will be returned with all available
data. This table can be hard to navigate since it contains several different
tables within it. Each series is uniquely identified by the \code{series_info} column.
The \code{series_info} column is also split along the \code{v1} to \code{v5} columns.
A complete metadata of each series is available \href{https://www.bcb.gov.br/estatisticas/mercadoimobiliario}{here} (only in Portuguese).

Other choices of \code{category} return a wide \code{tibble} with informative column
names. Available options are: \code{'accounting'}, \code{'application'}, \code{'indices'},
\code{'sources'}, \code{'units'}, or \code{'all'}.
}
\examples{
\dontrun{
# Download all data in long format
bcb <- get_bcb_realestate()

# Get only data on financed units
units <- get_bcb_realestate("units")

}
}
