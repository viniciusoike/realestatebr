if (interactive()) {
  load_all()

  # [solved] Shouldn't show deprecation warning
  get_dataset("abrainc", table = "radar", source = "fresh")
  get_dataset("abrainc", table = "indicator", source = "fresh")
  get_dataset("abrainc", table = "leading", source = "fresh")

  # [solved] should load fast (i.e. from cache)
  get_dataset("abecip")
  get_dataset("abecip", table = "sbpe")
  get_dataset("abecip", table = "units")
  get_dataset("abecip", table = "cgi")

  # Test if 'fresh' source is working
  # Both work
  get_dataset("abecip", table = "sbpe", source = "fresh")
  get_dataset("abecip", table = "units", source = "fresh")

  # Messaging is confusing here
  # Downloading data from Abecip...
  # ℹ CGI data is a static historical dataset (January 2017-present)
  # ℹ Loading from package cache instead of fresh download
  # Loaded 'abecip' from cache
  # Successfully loaded CGI data from package cache
  # Successfully loaded Abecip CGI data from cache
  #
  # Is the data fresh or from cache?
  get_dataset("abecip", table = "cgi", source = "fresh")

  # Not working (as intended)
  get_dataset("bis_rppi", table = "detailed")
  get_dataset("rppi_bis", "detailed")

  # Working
  get_dataset("rppi_bis")
  # Cached version is failing because of name inconsistency
  get_dataset("rppi_bis", "detailed_monthly")
  get_dataset("rppi_bis", "detailed_quarterly")
  get_dataset("rppi_bis", "detailed_semiannual")
  get_dataset("rppi_bis", "detailed_annual")
  # Also: the name is a bit long, maybe remove the detailed_ prefix?

  # Do the fresh versions work?
  # NO!
  # Clousre error suggests a problem with the function definition
  # maybe something changed name in the environment?
  get_dataset("rppi_bis", "detailed_monthly", source = "fresh")
  get_dataset("rppi_bis", "detailed_quarterly", source = "fresh")
  get_dataset("rppi_bis", "detailed_semiannual", source = "fresh")
  get_dataset("rppi_bis", "detailed_annual", source = "fresh")

  # Solved
  # Should be renamed to fgv_ibre
  # fgv_indicators -> fgv_ibre
  get_dataset("fgv_ibge")

  # Solved
  # this is a static dataset with a single table
  # should work similar to fgv_ibre
  get_dataset("nre_ire")

  # [partially solved] Major problems with RPPI suite of functions

  # OK
  get_dataset("rppi")
  get_dataset("rppi", table = "ivgr")
  get_dataset("rppi", table = "igmi")
  get_dataset("rppi", table = "iqa")
  get_dataset("rppi", table = "ivar")

  fz <- get_dataset("rppi", table = "fipezap")
  # name_muni still uses Índice Fipezap -> should be "Brazil"
  fz

  # check if the fresh source is working
  fz <- get_dataset("rppi", table = "fipezap", source = "fresh")

  if ("Brazil" %in% unique(fz$name_muni)) {
    message("Good: 'Brazil' found in name_muni")
  } else {
    cli::cli_warn("Problem: 'Brazil' not found in name_muni")
  }

  sale <- get_dataset("rppi", table = "sale", source = "fresh")
  rent <- get_dataset("rppi", table = "rent", source = "fresh")
  all <- get_dataset("rppi", table = "all", source = "fresh")

  get_dataset("secovi", table = "launch")
  get_dataset("rppi", table = "all")

  # [solved] Table argument doesn't seem to be working. Always returns the same table
  # launch and salr aren't cached
  get_dataset("secovi", table = "condo")
  get_dataset("secovi", table = "launch")
  get_dataset("secovi", table = "sale")

  # Major problem with property_records
  # Most of the tables aren't working
  # Output is always a named list (should be a single tibble, following the pattern of other datasets)

  # Critical problem: still returning a named list!
  get_dataset("property_records")

  # Problem: doesn't work at all
  get_dataset("property_records", source = "fresh")
  # Returns a named list
  get_dataset("property_records", table = "capitals")
  # Doesn't work
  get_dataset("property_records", table = "capitals_transfers")
  # Doesn't work
  get_dataset("property_records", table = "cities")
  # Returns a named list
  get_dataset("property_records", table = "aggregates")
  # Doesn't work
  get_dataset("property_records", table = "aggregates_transfers")

  # Doesn't work
  get_dataset("property_records", source = "fresh")
}
