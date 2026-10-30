# Read one FINBRA "Receitas Orçamentárias (Anexo I-C)" bulk file

`path` may be a `.csv` or a `.zip` whose single CSV entry is read; the
exercise year comes from the `Exercício:` metadata line, never from file
names. The files are Windows-1252 (latin1) `;`-separated text whose
quoted account names may contain unescaped `"` and even `;`, so no
standard CSV reader is used: rows are identified by the fields read from
the end of the line (`Valor`, then `Identificador da Conta`), and tax
rows must keep exactly 8 fields.

## Usage

``` r
read_finbra_file(path, call = caller_env())
```

## Value

A tibble of tax rows in the long form (columns `year`, `code_muni`
(character, 7 digits), `abbrev_state`, `institution`, `tax`,
`value_kind`, `value`), carrying the attribute `reporters`: character
keys `<code_muni> <year>` of every municipality that has a valid data
line in the file (any account), not only tax rows; and the attribute
`context`: one tibble row per municipality-year with `current_revenue`
and `tax_revenue` (the gross realized values of the Current Revenue and
Taxes, Fees and Contributions accounts). The file's `População` field is
ignored: population comes from IBGE (see
[`fetch_siconfi_population()`](https://viniciusoike.github.io/realestatebr/reference/fetch_siconfi_population.md)).
