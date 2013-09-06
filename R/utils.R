# Find max value for column var across data frames
hist_x_axis_max <- function(dfs, var) {
  maxval = max(unlist(Map(function(x){max(x)}, Map(function(x){x$var}, dfs))))
}

### Data conversions

# printf for R
printf <- function(...) invisible(print(sprintf(...)))

# Trim whitespace from strings
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

# Decide whether a value is an integer
is.integer <- function(N){
  !length(grep("[^[:digit:]]", format(N, scientific = FALSE)))
}

# Load an preprocess all data
load.data <- function() {
  dfs <- load.all(dir=data.file.location, pattern="*.csv$")
  dfs <- addcol.merged(dfs)
  all <- merge.dataframes(dfs)
  subset(all, !is.na(src_churn))
}

# Load all csv files in the provided dir as data frames
load.all <- function(dir = ".", pattern = "*.csv$") {
  lapply(list.files(path = dir, pattern = pattern, full.names = T),
         function(x){
           print(sprintf("Reading file %s", x))
           a <- load.filter(x)
           if (nrow(a) == 0) {
            printf("Warning - No rows in file %s", x)
           }
           a
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
    df = load.filter(file)
    merged <- rbind(merged, addcol.merged.df(df))
  }
  merged
}

load.filter <- function(path) {
  setAs("character", "POSIXct", function(from){as.POSIXct(from, origin = "1970-01-01")})
  a <- read.csv(path, check.names = T, 
                colClasses = c("integer",rep("factor",3), rep("integer", 5),
                               rep("factor", 3), rep("integer", 9),
                               rep("double", 3), "integer",  "factor",
                               "integer", "double", "integer",
                               "factor", "factor"))

  a$conflict <- a$conflict == "true"
  a$conflict <- as.factor(a$conflict)
  a$forward_links <- a$forward_links == "true"
  a$forward_links <- as.factor(a$forward_links)
  a$main_team_member <- a$main_team_member == "true"
  a$main_team_member <- as.factor(a$main_team_member)
  a$intra_branch <- a$intra_branch == "true"
  a$intra_branch <- as.factor(a$intra_branch)
  # Take care of cases where csv file production was interupted, so the last
  # line has wrong fields
  a <- subset(a, !is.na(intra_branch))
  a
}

# Add merged column
addcol.merged <- function(dfs) {
  lapply(dfs, addcol.merged.df)
}

addcol.merged.df <- function(x) {
  print(sprintf("Adding column merged to dataframe %s", (project.name(x))))
  x$merged <- !is.na(x$merged_at)
  x$merged <- as.factor(x$merged)
  x
}

# Name of a project in a dataframe
project.name <- function(dataframe) {
  as.character(dataframe$project_name[[1]])
}

# Name of all projects in the provided dataframe list
project.names <- function(dfs) {
  lapply(dfs, project.name)
}

# Get a project dataframe from the provided data frame list whose name is dfs
get.project <- function(dfs, name) {
  Find(function(x){if(project.name(x) == name){T} else {F} }, dfs)
}

# Merge dataframes
merge.dataframes <- function(dfs, min_num_rows = 1) {
  Reduce(function(acc, x){
        printf("Merging dataframe %s", project.name(x))
        if (nrow(x) >= min_num_rows) {
          rbind(acc, x)
        } else {
          printf("Warning: %s has less than %d rows (%d), skipping", project.name(x), min_num_rows, nrow(x))
          acc
        }
      }, dfs)
}

# Prints a list of column along with a boolean value. If the value is FALSE, then
# the column contains at least one NA value
column.contains.na <- function(df) {
  for (b in colnames(df)){print(sprintf("%s %s", b, all(!is.na(a.train[[b]]))))}
}

# Run the Matt-Whitney test on input vectors a and b and report relevant metrics
ranksum <- function (a, b, title = "") {
  w <- wilcox.test(a, b)
  d <- cliffs.d(a, b)
  printf("%s sizes: a: %d b: %d, medians a: %f b: %f, means a: %f, b: %f, wilcox: %f, p: %f, d: %f", 
         title, length(a), length(b), median(a), median(b), mean(a), mean(b), w$statistic, 
         w$p.value, d)
}

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