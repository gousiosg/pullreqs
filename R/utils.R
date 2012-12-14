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

# Load all csv files in the provided dir as data frames
load.all <- function(dir = ".") {
  lapply(list.files(path = dir, pattern = "*.csv$", full.names = T),
         function(x){read.csv(pipe(paste("cut -f2-19 -d',' ", x)))})
}

# Merge all dataframes in the provided list into one dataframe
merge.dataframes <- function(dataframes) {
  merged <- data.frame()
  for (i in 1:length(dataframes)) {
    print(sprintf("Merging dataframe %d", i))
    merged <- rbind(merged, dataframes[[i]])
  }
  merged
}

# Store a plot as PDF. By default, will store to user's home directory
store <- function(printer, data, cols, name, where = "~/")
{
  pdf(paste(where, paste(name, "pdf", sep=".")), width = 11.7, height = 16.5, title = name)
  printer <- match.fun(printer)
  printer(data, cols)
  dev.off()
}