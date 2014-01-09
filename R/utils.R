#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

library(methods)

# printf for R
printf <- function(...) invisible(print(sprintf(...)))

unwrap <- function(str) {
  strwrap(str, width=10000, simplify=TRUE)
}

## Data loading and conversions

# Trim whitespace from strings
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

# Decide whether a value is an integer
is.integer <- function(N){
  !length(grep("[^[:digit:]]", format(N, scientific = FALSE)))
}

# Load an preprocess all data
load.data <- function(projects.file = "projects.txt") {
  all <- load.all.df(dir=data.file.location, pattern="*.csv$", projects.file)
  subset(all, !is.na(src_churn))
}

# Determine which files to load and return a list of paths
which.to.load <- function(dir = ".", pattern = "*.csv$",
                          projects.file = "projects.txt") {
  if(file.exists(projects.file)) {
    joiner <- function(x){
      owner <- x[[1]]
      repo <- x[[2]]
      sprintf("%s/%s@%s.csv", dir, owner, repo)
    }
    apply(read.csv(projects.file, sep = " ", header=FALSE), c(1), joiner)
  } else {
    list.files(path = dir, pattern = pattern, full.names = T)
  }
}

# Load all files matching the pattern as a single dataframe
load.all.df <- function(dir = ".", pattern = "*.csv$",
                        projects.file = "projects.txt") {
  script = "
    head -n 1 `head -n 1 to_load.txt`
    cat to_load.txt|while read f; do cat $f|sed -e 1d; done
  "
  to.load <- which.to.load(dir, pattern, projects.file)
  write.table(to.load, file='to_load.txt', row.names = FALSE, col.names = FALSE,
              quote = FALSE)
  printf("Loading %d files from %s", length(to.load), projects.file)
  tryCatch({
    load.filter(pipe(script))
  }, finally= {
    printf("Done loading files")
    unlink("to_load.txt")
  })
}

# Load all files matching the pattern as a list of data frames
# The projects_file argument specifies an optional list of files to load.
# If the provided projects_file does not exist, all data files will be loaded
load.all <- function(dir = ".", pattern = "*.csv$",
                     projects.file = "projects.txt") {

  to_load <- which.to.load(dir, pattern, projects.file)

  Reduce(function(acc, x) {
      if (file.exists(x)) {
         print(sprintf("Reading file %s", x))
         a <- load.filter(pipe(sprintf("cat %s", x)))
         if (nrow(a) == 0) {
          printf("Warning - No rows in file %s", x)
          acc
         } else {
           c(acc, list(a))
         }
      } else {
        printf("File does not exist %s", x)
        acc
      }
    }, to_load, c())
}

# Load some dataframes
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
  setAs("character", "POSIXct",
        function(from){as.POSIXct(from, origin = "1970-01-01")})
  a <- read.csv(path, check.names = T, 
                colClasses = c("integer",rep("factor",2), rep("integer", 6),
                               rep("factor", 3), rep("integer", 18),
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
  a$merged <- !is.na(a$merged_at)
  a$merged <- as.factor(a$merged)
  # Take care of cases where csv file production was interupted, so the last
  # line has wrong fields
  a <- subset(a, !is.na(intra_branch))
  a
}

# Name of a project in a dataframe
project.name <- function(dataframe) {
  as.character(dataframe$project_name[[1]])
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

## Various utilities

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

## Plot storage

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
