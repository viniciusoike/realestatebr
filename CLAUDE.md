# realestatebr Package - Claude Code Guidelines

## Project Overview

R package for Brazilian real estate market data, transitioning from web-scraping to a robust data distribution system with:
- Simple user interface (`list_datasets()`, `get_dataset()`)
- Automated data pipeline using {targets}
- DuckDB integration for large datasets
- Backward compatibility with existing `get_*()` functions
- Consistent PT→EN translation following geobr patterns

## Architecture Transition (3 Phases)

### Phase 1: Core Functions (Current)
- ✅ Add `list_datasets()` and `get_dataset()` functions
- ✅ Keep existing `get_*()` functions working
- ✅ Create dataset registry system (YAML)
- ✅ Implement caching system
- ✅ Translate column names to English

### Phase 2: Data Pipeline (Future)
- Implement {targets} workflow
- Add data validation and quality checks
- Set up automated updates

### Phase 3: Scale Up (Future)
- DuckDB integration for large datasets
- Add ITBI and IPTU data
- Lazy query support

## Key Commands
- Build: `R CMD build .`
- Check: `R CMD check realestatebr_*.tar.gz`
- Install: `R CMD INSTALL .`
- Test: `devtools::test()`
- Document: `devtools::document()`
- Load all: `devtools::load_all()`

## File Structure

```
realestatebr/
├── inst/extdata/
│   ├── datasets.yaml         # Dataset registry
│   ├── cache/                # Cached datasets
│   └── documentation/        # Temporary docs needing review
├── R/
│   ├── list-datasets.R       # Dataset discovery
│   ├── get-dataset.R         # Unified data access
│   ├── translation.R         # PT→EN translation utilities
│   ├── validation.R          # Data validation
│   ├── cache.R              # Caching utilities
│   └── get-*.R              # Legacy functions (kept for compatibility)
├── data-raw/                # Data processing scripts
├── cached_data/             # GitHub-hosted cache
└── tests/testthat/         # Unit tests
```

## Development Patterns

### Function Workflow
- `import_*()`: Web scraping/API calls (internal)
- `clean_*()`: Data transformation (internal)
- `get_*()`: User-facing functions (exported)
- `list_datasets()`: Dataset discovery (exported)
- `get_dataset()`: Unified access (exported)

### Translation Standards (PT→EN)
Follow geobr package patterns:
```r
# Geographic
estado → state
municipio → municipality
regiao → region

# Time
ano → year
mes → month
data → date

# Values
valor → value
preco → price
indice → index
taxa → rate

# Real estate
lancamentos → launches
vendas → sales
unidades → units
financiamento → financing
aluguel → rent
```

### Error Handling Pattern
```r
get_dataset <- function(name, source = "auto") {
  tryCatch({
    load_from_cache(name)      # Try cache first
  }, error = function(e) {
    tryCatch({
      download_from_github(name) # Try GitHub
    }, error = function(e2) {
      download_fresh(name)       # Fresh download
    })
  })
}
```

### Documentation Requirements
- Never create fake documentation
- Mark uncertain docs as temporary in `inst/extdata/documentation/temp_docs.md`
- Use educated guesses based on column names
- Flag for expert review

## Dataset Registry (datasets.yaml)

```yaml
datasets:
  dataset_name:
    name: "English name"
    name_pt: "Nome em português"
    description: "Clear description"
    source: "Data source"
    url: "Source URL"
    geography: "Coverage"
    frequency: "Update frequency"
    coverage: "Time period"
    categories:
      - name: "description"
    legacy_function: "get_*"
    data_type: "tibble|list"
    translation_notes: "Notes on translations"
```

## Priority Datasets for Migration

1. **abecip_indicators** - Housing credit (sbpe, units, cgi)
2. **abrainc_indicators** - Primary market (indicator, radar, leading)
3. **bcb_realestate** - Central Bank data (5 categories)
4. **secovi** - São Paulo market (4 categories)
5. **bis_rppi** - International price indices

## Code Conventions
- Use tidyverse style guide
- Use native pipe (`|>`)
- Explicit package calls in functions (`dplyr::filter()`)
- Document with roxygen2
- Use cli for messages
- Prefer readability over brevity
- Use `<-` for assignment
- Always use `return()` in functions
- Avoid long pipe chains (>5)

## Data Characteristics
- Most data from messy Excel files (non-tidy)
- Original data in Portuguese
- Requires robust parsing
- Handle missing values gracefully
- Validate data structure

## Testing Strategy
```r
test_that("dataset loads correctly", {
  data <- get_dataset("dataset_name")
  expect_true(nrow(data) > 0)
  expect_true(all(required_cols %in% names(data)))
})
```

## Important Principles

1. **Backward Compatibility**: All existing functions must continue working
2. **Never Fake Data**: Use only real data
3. **Document Uncertainty**: Mark unclear documentation as temporary
4. **Consistent Translation**: Follow established PT→EN patterns
5. **Graceful Degradation**: Multiple fallback data sources
6. **Handle Messy Data**: Robust parsing for non-tidy Excel structures

## Common Tasks

### Adding a New Dataset
1. Create processing script in `data-raw/`
2. Add entry to `datasets.yaml`
3. Update `get_dataset()` routing
4. Create documentation in `R/data-*.R`
5. Add tests in `tests/testthat/`

### Updating Documentation
- Focus on `@examples` with realistic use cases
- Include `@format` for data structure
- Add `@source` with attribution
- Use `@seealso` for related functions

## Package Mission

Create the definitive R package for Brazilian real estate data - reliable, well-documented, and easy to use for researchers, analysts, and data scientists working with the Brazilian real estate market.
