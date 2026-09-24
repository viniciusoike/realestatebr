## Submission

This minor release adds `query_dataset()` for lazy access to large relational
datasets, two IBGE construction datasets, and bug fixes.

## R CMD check results

0 errors | 0 warnings | 1 note

* The maintainer name is now "Vinicius Oike" instead of "Vinicius Oike
  Reginatto". The email address is unchanged.

* The URLs <https://sidra.ibge.gov.br/tabela/2296> and
  <https://sidra.ibge.gov.br/tabela/8886> return 403 to automated requests.
  They are the official IBGE SIDRA table pages and open in a web browser.

* <https://www.secovi.com.br> occasionally returns an empty reply to the URL
  checker. The site is available.
