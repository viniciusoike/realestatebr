## Submission

This minor release adds `query_dataset()` for lazy access to large relational
datasets, IBGE construction datasets, Minha Casa, Minha Vida housing program
data, and bug fixes. Version 1.1.0 was released on GitHub only, so this
submission covers the changes in both 1.1.0 and 1.2.0.

## R CMD check results

0 errors | 0 warnings | 1 note

* The maintainer name is now "Vinicius Oike" instead of "Vinicius Oike
  Reginatto". The email address is unchanged.

* The URLs under `sidra.ibge.gov.br` and `apisidra.ibge.gov.br` return
  403 Forbidden to automated requests because IBGE serves them behind a
  Cloudflare browser challenge. They open normally in a web browser and are
  the official catalogue pages for the IBGE tables the package reads.
