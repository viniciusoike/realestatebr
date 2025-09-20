
# Main goals

1. Have a complete functioning package. There are major problems with almost all functions. All functions should be working and returing a tibble.

2. Completely drop old arguments such as `category`. There is no need for backward compatibility since the package is still in version 0.x.y.

3. The get_* functions are not legacy, neither beign deprecated neither being replaced. They are the main functions of the package. The ONLY difference is that now they are INTERAL functions (not exported to the user). These functions are called by `get_dataset()`.

4. Remove `get_b3_stocks()` and its related dependencies.

### Details

THe `get_b3_stocks()` function brings {tidyquant} and {zoo} dependencies. These packages are not necessary for the main purpose of the package, which is to get datasets from Brazilian sources. Create a backup of this script inside the `old/` directory. Remove all references to this function in the documentation and vignettes. In the future, we will create an improved version of this function using the `rb3` package.

5. Simplify `get_bcb_series()`.

### Details
T
Currently, this function returns a lot of errors and too many series at once. Let's reduce it to only these series:

190
192
432
433
20704
20756
20768
20914
21072
21084
21340
24364
28545
28763
28770



# Minor goals

1. Define table as the second argument of `get_dataset()`. Set `source` as the third argument.

```r
# Current
get_dataset("abecip", table = "sbpe")

# Proposed
get_dataset("abecip", "sbpe")

# Syntax
get_dataset(name, table, source)
```

This makes it easier for the user.
