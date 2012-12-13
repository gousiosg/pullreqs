# Find max value for column var across data frames
hist_x_axis_max <- function(dfs, var) {
  maxval = max(unlist(Map(function(x){max(x)}, Map(function(x){x$var}, dfs))))
}

# Names of all projects in dataframes
projects <- function(dfs) {
  nam
}

### Data conversions

# Trim whitespace from strings
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

# Decide whether a value is an integer
is.integer <- function(N){
  !length(grep("[^[:digit:]]", format(N, scientific = FALSE)))
}
