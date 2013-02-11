# Find max value for column var across data frames
hist_x_axis_max <- function(dfs, var) {
  maxval = max(unlist(Map(function(x){max(x)}, Map(function(x){x$var}, dfs))))
}

### Data conversions

# Trim whitespace from strings
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

# Decide whether a value is an integer
is.integer <- function(N){
  !length(grep("[^[:digit:]]", format(N, scientific = FALSE)))
}

# Load all csv files in the provided dir as data frames
load.all <- function(dir = ".", pattern = "*.csv$") {
  lapply(list.files(path = dir, pattern = pattern, full.names = T),
         function(x){
           print(sprintf("Reading file %s", x))
           read.csv(pipe(paste("cut -f2-25 -d',' ", x)), check.names = T)
         })
}

load.some <- function(dir = ".", pattern = "*.csv$", howmany = -1) {
  n = 0
  merged <- data.frame()
  for (file in list.files(path = dir, pattern = pattern, full.names = T)) {
    n = n + 1
    if (howmany < n) {
      return(merged)
    }
    print(sprintf("Reading file %s", file))
    df = read.csv(pipe(paste("cut -f2-25 -d',' ", file)), check.names = T)
    merged <- rbind(merged, df)
  }
  merged
}

# Add merged column
addcol.merged <- function(dfs) {
  lapply(dfs, addcol.merged.df)
}

addcol.merged.df <- function(x) {
  print(sprintf("Adding column merged to dataframe %s", (project.name(x))))
  x$merged <- apply(x, 1, function(r){if(is.na(r[['merged_at']])){F} else {T}})
  x$merged <- as.factor(x$merged)
  x
}

# Name of a project in a dataframe
project.name <- function(dataframe) {
  as.character(unique(dataframe[['project_name']]))
}

# Name of all projects in the provided dataframe list
project.names <- function(dfs) {
  lapply(dfs, project.name)
}

# Get a project dataframe from the provided data frame list whose name is dfs
get.project <- function(dfs, name) {
  Find(function(x){if(project.name(x) == name){T} else {F} }, dfs)
}

# Merge all dataframes in the provided list into one dataframe
merge.dataframes <- function(dataframes) {
  merged <- data.frame()
  for (i in 1:length(dataframes)) {
    print(sprintf("Merging dataframe %s", project.name(dataframes[[i]])))    
    merged <- rbind(merged, dataframes[[i]])
  }
  merged
}

# Prints a list of column along with a boolean value. If the value is FALSE, then
# the column contains at least one NA value
column.contains.na <- function(df) {
  for (b in colnames(df)){print(sprintf("%s %s", b, all(!is.na(a.train[[b]]))))}
}

# Saving plots as PDFs

# Store multiple plots on the same PDF
store.multi <- function(printer, data, cols, name, where = "~/")
{
  pdf(paste(where, paste(name, "pdf", sep=".")), width = 11.7, height = 16.5, title = name)
  printer <- match.fun(printer)
  printer(data, cols)
  dev.off()
}

# Store a plot as PDF. By default, will store to user's home directory
store.pdf <- function(data, where, name)
{
  pdf(paste(where,name, sep="/"))
  plot(data)
  dev.off()
}