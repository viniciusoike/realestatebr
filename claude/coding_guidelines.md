# Modern R Development Guide

*This document captures current best practices for R development, emphasizing modern tidyverse patterns, performance, and style. Last updated: August 2025*

## Core Principles

1. **Use modern tidyverse patterns** - Prioritize dplyr 1.1+ features, native pipe, and current APIs
2. **Profile before optimizing** - Use profvis and bench to identify real bottlenecks
3. **Write readable code first** - Optimize only when necessary and after profiling
4. **Follow tidyverse style guide** - Consistent naming, spacing, and structure
5. **Use {cli}** for messages, errors, warnings, etc. Be concise and informative.

## Modern Tidyverse Patterns

### Pipe Usage (`|>` not `%>%`)
- **Always use native pipe `|>` instead of magrittr `%>%`**
- R 4.3+ provides all needed features
```r
# Good - Modern native pipe
data |>
  filter(year >= 2020) |>
  summarise(mean_value = mean(value))

# Avoid - Legacy magrittr pipe
data %>%
  filter(year >= 2020) %>%
  summarise(mean_value = mean(value))
```

- Don't use pipe for single function calls (i.e. don't `x |> mean()`).
- Don't make pipe chains too long (5-7 should be the limit): break into smaller steps.

### Join Syntax (dplyr 1.1+)
- **Use `join_by()` instead of character vectors for joins**
- **Support for inequality, rolling, and overlap joins**
```r
# Good - Modern join syntax
transactions |>
  inner_join(companies, by = join_by(company == id))

# Good - Inequality joins
transactions |>
  inner_join(companies, join_by(company == id, year >= since))

# Good - Rolling joins (closest match)
transactions |>
  inner_join(companies, join_by(company == id, closest(year >= since)))

# Avoid - Old character vector syntax
transactions |>
  inner_join(companies, by = c("company" = "id"))
```

### Multiple Match Handling
- **Use `multiple` and `unmatched` arguments for quality control**
```r
# Expect 1:1 matches, error on multiple
inner_join(x, y, by = join_by(id), multiple = "error")

# Allow multiple matches explicitly
inner_join(x, y, by = join_by(id), multiple = "all")

# Ensure all rows match
inner_join(x, y, by = join_by(id), unmatched = "error")
```

### Data Masking and Tidy Selection
- **Understand the difference between data masking and tidy selection**
- **Use `{{}}` (embrace) for function arguments**
- **Use `.data[[]]` for character vectors**

```r
# Data masking functions: arrange(), filter(), mutate(), summarise()
# Tidy selection functions: select(), relocate(), across()

# Function arguments - embrace with {{}}
my_summary <- function(data, group_var, summary_var) {
  data |>
    group_by({{ group_var }}) |>
    summarise(mean_val = mean({{ summary_var }}))
}

# Character vectors - use .data[[]]
for (var in names(mtcars)) {
  mtcars |> count(.data[[var]]) |> print()
}

# Multiple columns - use across()
data |>
  summarise(across({{ summary_vars }}, ~ mean(.x, na.rm = TRUE)))
```

### Modern Grouping and Column Operations
- **Use `.by` for per-operation grouping (dplyr 1.1+)**
- **Use `pick()` for column selection inside data-masking functions**
- **Use `across()` for applying functions to multiple columns**
- **Use `reframe()` for multi-row summaries**

```r
# Good - Per-operation grouping (always returns ungrouped)
data |>
  summarise(mean_value = mean(value), .by = category)

# Good - Multiple grouping variables
data |>
  summarise(total = sum(revenue), .by = c(company, year))

# Good - pick() for column selection
data |>
  summarise(
    n_x_cols = ncol(pick(starts_with("x"))),
    n_y_cols = ncol(pick(starts_with("y")))
  )

# Good - across() for applying functions
data |>
  summarise(across(where(is.numeric), mean, .names = "mean_{.col}"), .by = group)

# Good - reframe() for multi-row results
data |>
  reframe(quantiles = quantile(x, c(0.25, 0.5, 0.75)), .by = group)

# Avoid - Old persistent grouping pattern
data |>
  group_by(category) |>
  summarise(mean_value = mean(value)) |>
  ungroup()
```

## Modern rlang Patterns for Data-Masking

### Core Concepts

**Data-masking** allows R expressions to refer to data frame columns as if they were variables in the environment. rlang provides the metaprogramming framework that powers tidyverse data-masking.

#### Key rlang Tools
- **Embracing `{{}}`** - Forward function arguments to data-masking functions
- **Injection `!!`** - Inject single expressions or values
- **Splicing `!!!`** - Inject multiple arguments from a list
- **Dynamic dots** - Programmable `...` with injection support
- **Pronouns `.data`/`.env`** - Explicit disambiguation between data and environment variables

### Function Argument Patterns

#### Forwarding with `{{}}`
**Use `{{}}` to forward function arguments to data-masking functions:**

```r
# Single argument forwarding
my_summarise <- function(data, var) {
  data |> dplyr::summarise(mean = mean({{ var }}))
}

# Works with any data-masking expression
mtcars |> my_summarise(cyl)
mtcars |> my_summarise(cyl * am)
mtcars |> my_summarise(.data$cyl)  # pronoun syntax supported
```

#### Forwarding `...` (No Special Syntax Needed)
```r
# Simple dots forwarding
my_group_by <- function(.data, ...) {
  .data |> dplyr::group_by(...)
}

# Works with tidy selections too
my_select <- function(.data, ...) {
  .data |> dplyr::select(...)
}

# For single-argument tidy selections, wrap in c()
my_pivot_longer <- function(.data, ...) {
  .data |> tidyr::pivot_longer(c(...))
}
```

#### Names Patterns with `.data`
**Use `.data` pronoun for programmatic column access:**

```r
# Single column by name
my_mean <- function(data, var) {
  data |> dplyr::summarise(mean = mean(.data[[var]]))
}

# Usage - completely insulated from data-masking
mtcars |> my_mean("cyl")  # No ambiguity, works like regular function

# Multiple columns with all_of()
my_select_vars <- function(data, vars) {
  data |> dplyr::select(all_of(vars))
}

mtcars |> my_select_vars(c("cyl", "am"))
```

### Injection Operators

#### When to Use Each Operator

| Operator | Use Case | Example |
|----------|----------|---------|
| `{{ }}` | Forward function arguments | `summarise(mean = mean({{ var }}))` |
| `!!` | Inject single expression/value | `summarise(mean = mean(!!sym(var)))` |
| `!!!` | Inject multiple arguments | `group_by(!!!syms(vars))` |
| `.data[[]]` | Access columns by name | `mean(.data[[var]])` |

#### Advanced Injection with `!!`
```r
# Create symbols from strings
var <- "cyl"
mtcars |> dplyr::summarise(mean = mean(!!sym(var)))

# Inject values to avoid name collisions
df <- data.frame(x = 1:3)
x <- 100
df |> dplyr::mutate(scaled = x / !!x)  # Uses both data and env x

# Use data_sym() for tidyeval contexts (more robust)
mtcars |> dplyr::summarise(mean = mean(!!data_sym(var)))
```

#### Splicing with `!!!`
```r
# Multiple symbols from character vector
vars <- c("cyl", "am")
mtcars |> dplyr::group_by(!!!syms(vars))

# Or use data_syms() for tidy contexts
mtcars |> dplyr::group_by(!!!data_syms(vars))

# Splice lists of arguments
args <- list(na.rm = TRUE, trim = 0.1)
mtcars |> dplyr::summarise(mean = mean(cyl, !!!args))
```

### Dynamic Dots Patterns

#### Using `list2()` for Dynamic Dots Support
```r
my_function <- function(...) {
  # Collect with list2() instead of list() for dynamic features
  dots <- list2(...)
  # Process dots...
}

# Enables these features:
my_function(a = 1, b = 2)           # Normal usage
my_function(!!!list(a = 1, b = 2))  # Splice a list
my_function("{name}" := value)      # Name injection
my_function(a = 1, )               # Trailing commas OK
```

#### Name Injection with Glue Syntax
```r
# Basic name injection
name <- "result"
list2("{name}" := 1)  # Creates list(result = 1)

# In function arguments with {{
my_mean <- function(data, var) {
  data |> dplyr::summarise("mean_{{ var }}" := mean({{ var }}))
}

mtcars |> my_mean(cyl)        # Creates column "mean_cyl"
mtcars |> my_mean(cyl * am)   # Creates column "mean_cyl * am"

# Allow custom names with englue()
my_mean <- function(data, var, name = englue("mean_{{ var }}")) {
  data |> dplyr::summarise("{name}" := mean({{ var }}))
}

# User can override default
mtcars |> my_mean(cyl, name = "cylinder_mean")
```

### Pronouns for Disambiguation

#### `.data` and `.env` Best Practices
```r
# Explicit disambiguation prevents masking issues
cyl <- 1000  # Environment variable

mtcars |> dplyr::summarise(
  data_cyl = mean(.data$cyl),    # Data frame column
  env_cyl = mean(.env$cyl),      # Environment variable
  ambiguous = mean(cyl)          # Could be either (usually data wins)
)

# Use in loops and programmatic contexts
vars <- c("cyl", "am")
for (var in vars) {
  result <- mtcars |> dplyr::summarise(mean = mean(.data[[var]]))
  print(result)
}
```

### Programming Patterns

#### Bridge Patterns
**Converting between data-masking and tidy selection behaviors:**

```r
# across() as selection-to-data-mask bridge
my_group_by <- function(data, vars) {
  data |> dplyr::group_by(across({{ vars }}))
}

# Works with tidy selection
mtcars |> my_group_by(starts_with("c"))

# across(all_of()) as names-to-data-mask bridge
my_group_by <- function(data, vars) {
  data |> dplyr::group_by(across(all_of(vars)))
}

mtcars |> my_group_by(c("cyl", "am"))
```

#### Transformation Patterns
```r
# Transform single arguments by wrapping
my_mean <- function(data, var) {
  data |> dplyr::summarise(mean = mean({{ var }}, na.rm = TRUE))
}

# Transform dots with across()
my_means <- function(data, ...) {
  data |> dplyr::summarise(across(c(...), ~ mean(.x, na.rm = TRUE)))
}

# Manual transformation (advanced)
my_means_manual <- function(.data, ...) {
  vars <- enquos(..., .named = TRUE)
  vars <- purrr::map(vars, ~ expr(mean(!!.x, na.rm = TRUE)))
  .data |> dplyr::summarise(!!!vars)
}
```

### Error-Prone Patterns to Avoid

#### Don't Use These Deprecated/Dangerous Patterns
```r
# Avoid - String parsing and eval (security risk)
var <- "cyl"
code <- paste("mean(", var, ")")
eval(parse(text = code))  # Dangerous!

# Good - Symbol creation and injection
!!sym(var)  # Safe symbol injection

# Avoid - get() in data mask (name collisions)
with(mtcars, mean(get(var)))  # Collision-prone

# Good - Explicit injection or .data
with(mtcars, mean(!!sym(var)))  # Safe
# or
mtcars |> summarise(mean(.data[[var]]))  # Even safer
```

#### Common Mistakes
```r
# Don't use {{ }} on non-arguments
my_func <- function(x) {
  x <- force(x)  # x is now a value, not an argument
  quo(mean({{ x }}))  # Wrong! Captures value, not expression
}

# Don't mix injection styles unnecessarily
# Pick one approach and stick with it:
# Either: embrace pattern
my_func <- function(data, var) data |> summarise(mean = mean({{ var }}))
# Or: defuse-and-inject pattern
my_func <- function(data, var) {
  var <- enquo(var)
  data |> summarise(mean = mean(!!var))
}
```

### Package Development with rlang

#### Import Strategy
```r
# In DESCRIPTION:
Imports: rlang

# In NAMESPACE, import specific functions:
importFrom(rlang, enquo, enquos, expr, !!!, :=)

# Or import key functions:
#' @importFrom rlang := enquo enquos
```

#### Documentation Tags
```r
#' @param var <[`data-masked`][dplyr::dplyr_data_masking]> Column to summarize
#' @param ... <[`dynamic-dots`][rlang::dyn-dots]> Additional grouping variables
#' @param cols <[`tidy-select`][dplyr::dplyr_tidy_select]> Columns to select
```

#### Testing rlang Functions
```r
# Test data-masking behavior
test_that("function supports data masking", {
  result <- my_function(mtcars, cyl)
  expect_equal(names(result), "mean_cyl")

  # Test with expressions
  result2 <- my_function(mtcars, cyl * 2)
  expect_true("mean_cyl * 2" %in% names(result2))
})

# Test injection behavior
test_that("function supports injection", {
  var <- "cyl"
  result <- my_function(mtcars, !!sym(var))
  expect_true(nrow(result) > 0)
})
```

This modern rlang approach enables clean, safe metaprogramming while maintaining the intuitive data-masking experience users expect from tidyverse functions.

## Function Writing Best Practices

### Structure and Style
```r
# Good function structure
rescale01 <- function(x) {
  rng <- range(x, na.rm = TRUE, finite = TRUE)
  scaled <- (x - rng[1]) / (rng[2] - rng[1])
  return(scaled)
}

# Use type-stable outputs
map_dbl()   # returns numeric vector
map_chr()   # returns character vector
map_lgl()   # returns logical vector
```

### Naming and Arguments
```r
# Good naming: snake_case for variables/functions
calculate_mean_score <- function(data, score_col) {
  # Function body
}

# Prefix non-standard arguments with .
my_function <- function(.data, ...) {
  # Reduces argument conflicts
}
```

## Style Guide Essentials

### Object Names
- **Use snake_case for all names**
- **Variable names = nouns, function names = verbs**
- **Avoid dots except for S3 methods**

```r
# Good
day_one
calculate_mean
user_data

# Avoid
DayOne
calculate.mean
userData
```

### Spacing and Layout
```r
# Pipe formatting
data |>
  filter(year >= 2020) |>
  group_by(category) |>
  summarise(
    mean_value = mean(value),
    count = n()
  )
```

## Common Anti-Patterns to Avoid

### Legacy Patterns
```r
# Avoid - Old pipe
data %>% function()

# Avoid - Old join syntax
inner_join(x, y, by = c("a" = "b"))

# Avoid - Implicit type conversion
sapply()  # Use map_*() instead

# Avoid - String manipulation in data masking
mutate(data, !!paste0("new_", var) := value)
# Use across() or other approaches instead
```

### Performance Anti-Patterns
```r
# Avoid - Growing objects in loops
result <- c()
for(i in 1:n) {
  result <- c(result, compute(i))  # Slow!
}

# Good - Pre-allocate
result <- vector("list", n)
for(i in 1:n) {
  result[[i]] <- compute(i)
}

# Better - Use purrr
result <- map(1:n, compute)
```

#### Tidyverse Dependency Guidelines
```r
# Core tidyverse (usually worth it):
dplyr     # Complex data manipulation
purrr     # Functional programming, parallel
stringr   # String manipulation
tidyr     # Data reshaping

# Specialized tidyverse (evaluate carefully):
lubridate # If heavy date manipulation
forcats   # If many categorical operations
readr     # If specific file reading needs
ggplot2   # If package creates visualizations

# Heavy dependencies (use sparingly):
tidyverse # Meta-package, very heavy
shiny     # Only for interactive apps
```

### API Design Patterns

#### Function Design Strategy
```r
# Modern tidyverse API patterns

# 1. Use .by for per-operation grouping
my_summarise <- function(.data, ..., .by = NULL) {
  # Support modern grouped operations
}

# 2. Use {{ }} for user-provided columns
my_select <- function(.data, cols) {
  .data |> select({{ cols }})
}

# 3. Use ... for flexible arguments
my_mutate <- function(.data, ..., .by = NULL) {
  .data |> mutate(..., .by = {{ .by }})
}

# 4. Return consistent types (tibbles, not data.frames)
my_function <- function(.data) {
  result |> tibble::as_tibble()
}
```

#### Input Validation Strategy
```r
# Validation level by function type:

# User-facing functions - comprehensive validation
user_function <- function(x, threshold = 0.5) {
  # Check all inputs thoroughly
  if (!is.numeric(x)) stop("x must be numeric")
  if (!is.numeric(threshold) || length(threshold) != 1) {
    stop("threshold must be a single number")
  }
  # ... function body
}

# Internal functions - minimal validation
.internal_function <- function(x, threshold) {
  # Assume inputs are valid (document assumptions)
  # Only check critical invariants
  # ... function body
}

# Package functions with vctrs - type-stable validation
safe_function <- function(x, y) {
  x <- vec_cast(x, double())
  y <- vec_cast(y, double())
  # Automatic type checking and coercion
}
```

### Error Handling Patterns

```r
# Good error messages - specific and actionable
if (length(x) == 0) {
  cli::cli_abort(
    "Input {.arg x} cannot be empty.",
    "i" = "Provide a non-empty vector."
  )
}

# Include function name in errors
validate_input <- function(x, call = caller_env()) {
  if (!is.numeric(x)) {
    cli::cli_abort("Input must be numeric", call = call)
  }
}

# Use consistent error styling
# cli package for user-friendly messages
# rlang for developer tools
```
### Testing and Documentation Strategy

#### Testing Levels
```r
# Unit tests - individual functions
test_that("function handles edge cases", {
  expect_equal(my_func(c()), expected_empty_result)
  expect_error(my_func(NULL), class = "my_error_class")
})

# Integration tests - workflow combinations
test_that("pipeline works end-to-end", {
  result <- data |>
    step1() |>
    step2() |>
    step3()
  expect_s3_class(result, "expected_class")
})

# Property-based tests for package functions
test_that("function properties hold", {
  # Test invariants across many inputs
})
```

#### Documentation Priorities
```r
# Must document:
✓ All exported functions
✓ Complex algorithms or formulas
✓ Non-obvious parameter interactions
✓ Examples of typical usage

# Can skip documentation:
✗ Simple internal helpers
✗ Obvious parameter meanings
✗ Functions that just call other functions
```

## Migration Notes

### From Base R to Modern Tidyverse
```r
# Data manipulation
subset(data, condition)         -> filter(data, condition)
data[order(data$x), ]           -> arrange(data, x)
aggregate(x ~ y, data, mean)    -> summarise(data, mean(x), .by = y)

# Functional programming
sapply(x, f)                    -> map(x, f)  # type-stable
lapply(x, f)                    -> map(x, f)

# String manipulation
grepl("pattern", text)          -> str_detect(text, "pattern")
gsub("old", "new", text)        -> str_replace_all(text, "old", "new")
substr(text, 1, 5)              -> str_sub(text, 1, 5)
nchar(text)                     -> str_length(text)
strsplit(text, ",")             -> str_split(text, ",")
paste0(a, b)                    -> str_c(a, b)
tolower(text)                   -> str_to_lower(text)
```

### From Old to New Tidyverse Patterns
```r
# Grouping (dplyr 1.1+)
group_by(data, x) |>
  summarise(mean(y)) |>
  ungroup()                     -> summarise(data, mean(y), .by = x)

# Column selection
across(starts_with("x"))        -> pick(starts_with("x"))  # for selection only

# Joins
by = c("a" = "b")              -> by = join_by(a == b)

# Multi-row summaries
summarise(data, x, .groups = "drop") -> reframe(data, x)

# Data reshaping
gather()/spread()               -> pivot_longer()/pivot_wider()

# String separation (tidyr 1.3+)
separate(col, into = c("a", "b")) -> separate_wider_delim(col, delim = "_", names = c("a", "b"))
extract(col, into = "x", regex)   -> separate_wider_regex(col, patterns = c(x = regex))
```

### Performance Migrations
```r
# Old -> New performance patterns
for loops for parallelizable work -> map(data, in_parallel(f))
Manual type checking             -> vec_assert() / vec_cast()
Inconsistent coercion           -> vec_ptype_common() / vec_c()

# Superseded purrr functions (purrr 1.0+)
map_dfr(x, f)                   -> map(x, f) |> list_rbind()
map_dfc(x, f)                   -> map(x, f) |> list_cbind()
map2_dfr(x, y, f)               -> map2(x, y, f) |> list_rbind()
pmap_dfr(list, f)               -> pmap(list, f) |> list_rbind()
imap_dfr(x, f)                  -> imap(x, f) |> list_rbind()

# For side effects
walk(x, write_file)             # instead of for loops
walk2(data, paths, write_csv)   # multiple arguments
```

This document should be referenced for all R development to ensure modern, performant, and maintainable code.
