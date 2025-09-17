# R Package Function Update Workflow

*A comprehensive checklist for modernizing functions in the realestatebr package to follow Phase 1 architecture and coding guidelines.*

## Overview

This workflow ensures all functions in the realestatebr package follow modern R development patterns, maintain consistency with the unified dataset architecture, and provide excellent user experience through robust error handling and progress reporting.

---

## Phase 1: Analysis & Assessment

### 1. Analyze Existing Function
- [ ] **Review function documentation and purpose**
  - Read roxygen2 docs and understand intended functionality
  - Check examples and identify use cases
  - Note any special requirements or constraints

- [ ] **Identify all dependencies**
  - Map internal function calls within package
  - List external package dependencies
  - Check for hidden dependencies in examples/tests

- [ ] **Map data flow and transformations**
  - Trace data from input to output
  - Identify transformation steps
  - Note any complex logic that could be extracted

- [ ] **Note current error handling approach**
  - Check for `stop()`, `warning()`, `message()` usage
  - Identify areas lacking error handling
  - Look for `try()`, `tryCatch()` patterns

### 2. Verify Structure Compliance
- [ ] **Check alignment with package architecture**
  - Verify Phase 1/2/3 status in CLAUDE.md
  - Ensure function fits overall package design
  - Check if function should use unified dataset architecture

- [ ] **Ensure follows established naming conventions**
  - Function names use snake_case
  - Functions are verbs, variables are nouns
  - Internal functions prefixed with `.` or documented with `@keywords internal`

- [ ] **Verify proper file organization**
  - R/ contains function definitions
  - data-raw/ contains data processing scripts
  - tests/ contains corresponding test files
  - man/ contains generated documentation

- [ ] **Check roxygen2 documentation completeness**
  - All parameters documented with `@param`
  - Return value documented with `@return`
  - Examples provided with `@examples`
  - `@export` for user-facing functions

### 3. Verify Coding Guidelines
- [ ] **Native pipe `|>` usage (not `%>%`)**
  ```r
  # Good
  data |> filter() |> select()

  # Avoid
  data %>% filter() %>% select()
  ```

- [ ] **Modern tidyverse patterns**
  - Use `.by` instead of `group_by()` + `ungroup()`
  - Use `join_by()` instead of character vectors
  - Use `reframe()` for multi-row summaries
  - Use `pick()` for column selection in data-masking

- [ ] **Proper use of cli for messages/errors**
  ```r
  cli::cli_inform()  # For informational messages
  cli::cli_warn()    # For warnings
  cli::cli_abort()   # For errors
  ```

- [ ] **Function naming and structure**
  - snake_case for all names
  - Meaningful parameter names
  - Logical parameter ordering

- [ ] **Error handling patterns**
  ```r
  tryCatch({
    # Try primary method
  }, error = function(e) {
    # Fallback method
  })
  ```

---

## Phase 2: Integration & Consistency

### 4. Check Dataset Architecture Integration
- [ ] **Verify integration with `get_dataset()` and `list_datasets()`**
  - Function accessible through `get_dataset("dataset_name")`
  - Consistent return types (tibbles)
  - Proper metadata attributes

- [ ] **Check dataset registry (datasets.yaml) entries**
  - Dataset properly registered in `inst/extdata/datasets.yaml`
  - Complete metadata (source, description, etc.)
  - Proper categorization

- [ ] **Ensure cached data handling follows unified pattern**
  ```r
  if (cached) {
    data <- get_dataset("dataset_name", source = "github")
    return(data)
  }
  ```

- [ ] **Validate metadata attributes**
  ```r
  attr(data, "source") <- "web"
  attr(data, "download_time") <- Sys.time()
  attr(data, "download_info") <- list(...)
  ```

### 5. Verify Web Scraping/API Calls
- [ ] **Implement retry logic with exponential backoff**
  ```r
  attempts <- 0
  while (attempts < max_retries) {
    # Try download
    if (attempts > 1) {
      Sys.sleep(min(attempts * 2, 5)) # Progressive backoff
    }
  }
  ```

- [ ] **Add proper error messages using cli**
  ```r
  cli::cli_abort(c(
    "Failed to download data",
    "x" = "Error: {error_message}",
    "i" = "Check your internet connection"
  ))
  ```

- [ ] **Include rate limiting and respectful delays**
  - Add delays between requests
  - Use appropriate user agents
  - Respect robots.txt

- [ ] **Validate downloaded data before processing**
  - Check file exists and has content
  - Validate expected structure
  - Handle empty or corrupted downloads

- [ ] **Handle partial failures gracefully**
  - Continue with successful downloads
  - Report failed items clearly
  - Provide options for strict vs. lenient behavior

---

## Phase 3: Optimization & Quality

### 6. Check for Duplicates & Redundancies
- [ ] **Search codebase for similar functions**
  ```bash
  # Use Grep tool to find similar patterns
  grep -r "pattern" R/
  ```

- [ ] **Identify shared helper functions to extract**
  - Look for repeated code blocks
  - Extract to utils.R or separate files
  - Use `@keywords internal` for internal functions

- [ ] **Look for repeated code patterns**
  - Data cleaning routines
  - Download/import patterns
  - Validation logic

- [ ] **Check if functionality exists in utils.R**
  - Review existing utility functions
  - Leverage existing helpers where possible

### 7. Identify Optimization Opportunities
- [ ] **Profile performance bottlenecks**
  ```r
  # Use profvis for profiling
  profvis::profvis({
    result <- your_function()
  })
  ```

- [ ] **Check for vectorization opportunities**
  - Replace loops with vectorized operations
  - Use `map_*()` family instead of `for` loops
  - Leverage dplyr's vectorized operations

- [ ] **Evaluate data.table vs dplyr for large datasets**
  - Consider data.table for >1M rows
  - Profile memory usage
  - Consider lazy evaluation

- [ ] **Consider parallel processing where applicable**
  - Use `furrr` for parallel map operations
  - Consider for independent downloads
  - Balance overhead vs. gains

- [ ] **Review memory usage patterns**
  - Avoid growing objects in loops
  - Pre-allocate when possible
  - Clean up temporary objects

---

## Phase 4: Testing & Validation

### 8. Test Updated Function
- [ ] **Run basic functionality tests**
  ```r
  # Test main function paths
  result1 <- get_function()
  result2 <- get_function(cached = TRUE)
  result3 <- get_function(category = "specific")
  ```

- [ ] **Test error conditions and edge cases**
  - Invalid parameters
  - Network failures (mock if needed)
  - Empty or corrupted data
  - Edge date ranges

- [ ] **Verify cached vs fresh data paths**
  - Test cache hit/miss scenarios
  - Verify fallback from cache to fresh
  - Check cache invalidation

- [ ] **Check all parameter combinations**
  - All category options
  - quiet = TRUE/FALSE
  - Different retry settings
  - Various date ranges

- [ ] **Validate output structure and content**
  - Check column names and types
  - Verify data ranges are reasonable
  - Test with real data sources
  - Validate metadata attributes

- [ ] **Test with quiet = TRUE/FALSE**
  - Verify progress reporting works
  - Check message suppression
  - Test progress bars

- [ ] **Verify retry logic works**
  - Mock network failures
  - Test exponential backoff
  - Verify final failure handling

---

## Phase 5: Documentation & Deployment

### 9. Update Documentation
- [ ] **Enhance roxygen2 documentation**
  ```r
  #' Enhanced Function Title
  #'
  #' Detailed description with modern features
  #'
  #' @section Progress Reporting:
  #' Description of progress features
  #'
  #' @section Error Handling:
  #' Description of error handling
  #'
  #' @param param Description
  #' @return Detailed return description
  #' @export
  #' @examples
  #' \dontrun{
  #' # Comprehensive examples
  #' }
  ```

- [ ] **Add/update examples**
  - Include quiet = FALSE example
  - Show error handling
  - Demonstrate different categories
  - Include metadata access

- [ ] **Include @section blocks for complex behavior**
  - Progress Reporting
  - Error Handling
  - Caching Strategy
  - Data Validation

- [ ] **Update vignettes if needed**
  - Add to getting-started vignette
  - Update any package overviews
  - Include in workflow examples

- [ ] **Ensure all parameters documented**
  - Complete @param entries
  - Document default values
  - Explain parameter interactions

### 10. Commit Changes
- [ ] **Run package checks**
  ```r
  devtools::check()
  devtools::test()
  lintr::lint_package()
  ```

- [ ] **Stage relevant files**
  ```bash
  git add R/get_function.R
  git add man/get_function.Rd  # if auto-generated
  git add tests/testthat/test-function.R  # if updated
  ```

- [ ] **Write descriptive commit message**
  ```
  Modernize get_function_name: Add robust error handling and CLI progress

  - Replace legacy patterns with modern tidyverse
  - Add retry logic for web scraping with exponential backoff
  - Implement CLI progress reporting and quiet mode
  - Add comprehensive input validation
  - Extract helper functions for clarity and reusability
  - Update documentation with enhanced examples and sections
  - Integrate with unified dataset architecture
  - Add data validation and metadata attributes

  🤖 Generated with Claude Code

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

- [ ] **Push to feature branch**
  ```bash
  git checkout -b modernize-function-name
  git push -u origin modernize-function-name
  ```

- [ ] **Create PR if applicable**
  - Link to relevant issues
  - Describe changes and rationale
  - Include testing notes

---

## Final Checklist Summary

### Code Quality
- [ ] Function follows modern R patterns (native pipe, modern dplyr)
- [ ] Error handling with graceful degradation implemented
- [ ] CLI messages provide clear user feedback
- [ ] Input validation is comprehensive and informative
- [ ] Code is DRY (Don't Repeat Yourself)

### Architecture & Integration
- [ ] Integrated with unified dataset architecture (get_dataset/list_datasets)
- [ ] Web scraping is robust with retry logic and rate limiting
- [ ] Helper functions extracted where appropriate
- [ ] Backward compatibility maintained

### Documentation & Testing
- [ ] Documentation complete with examples and sections
- [ ] Tests pass successfully (devtools::test())
- [ ] Package check passes (devtools::check())
- [ ] Performance acceptable for typical use cases

### Deployment
- [ ] Changes committed with descriptive message
- [ ] Feature branch created and pushed
- [ ] PR created if working in team environment

---

## Notes

- **Reference Implementation**: Use `get_b3_stocks.R` as the gold standard for modern function structure
- **Coding Guidelines**: Always refer to `claude/coding_guidelines.md` for detailed patterns
- **Package Status**: Check `CLAUDE.md` for current Phase 1/2/3 priorities
- **Testing**: Test with real data sources when possible, mock for reliability

This workflow ensures consistency across all package functions while maintaining high code quality and excellent user experience.