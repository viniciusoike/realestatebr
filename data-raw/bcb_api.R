library(rbcb)
library(GetBCBData)
library(purrr)

# Lets compare two APIs

# Try to download the full SELIC series (11, 04/06/1986)

safe_get_rbcb <- safely(rbcb::get_series)

get_selic_rbcb <- function() {
  selic_default <- safe_get_rbcb(11, start_date = NULL)
  selic_manual <- safe_get_rbcb(11, start_date = "1986-04-06")

  if (is.null(selic_default$error)) {
    selic_default <- selic_default$result
  } else {
    selic_default <- selic_default$error
  }

  if (is.null(selic_manual$error)) {
    selic_manual <- selic_manual$result
  } else {
    selic_manual <- selic_manual$error
  }

  return(list(
    default = selic_default,
    manual = selic_manual
  ))
}

# Important: rbcb will always fail on default values for daily series that
# exceed 10 years of data. This is a limitation of BACEN's API.

safe_get_gbcbd <- safely(GetBCBData::gbcbd_get_series)

get_selic_gbcbd <- function() {
  selic_default <- safe_get_gbcbd(11)
  selic_manual <- safe_get_gbcbd(11, first.date = "1986-04-06")

  if (is.null(selic_default$error)) {
    selic_default <- selic_default$result
  } else {
    selic_default <- selic_default$error
  }

  if (is.null(selic_manual$error)) {
    selic_manual <- selic_manual$result
  } else {
    selic_manual <- selic_manual$error
  }

  return(list(
    default = selic_default,
    manual = selic_manual
  ))
}

selic_gbcbd <- get_selic_gbcbd()

selic_gbcbd

GetBCBData::gbcbd_get_series(11, first.date = "1986-04-06")
