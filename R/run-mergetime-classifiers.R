#
# Merge time classifiers 2 bins
# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-time.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs)

run.mergetime.classifiers <- function(df, cases = c(1000, 10000, nrow(df)/4,
                                                    nrow(df)/2, nrow(df))) {
  for (i in cases) {
    data <- prepare.data.mergetime.4bins(df, i)
    results <- run.classifiers.mergetime(merge.time.model, data$train,
                                         data$test)
    cvResult <- cross.validation(merge.time.model,
                                 run.classifiers.mergetime,
                                 prepare.data.mergetime.4bins, df, i, 10)
    write.csv(cvResult, file = sprintf("merge-time-cv-%i.csv", i))
    cross.validation.plot(cvResult,
                          sprintf("Merge time task, 4 bins (%d items)", i),
                          sprintf("merge-time-cv-%d.pdf", i))
  }
}

run.mergetime.classifiers(all)
