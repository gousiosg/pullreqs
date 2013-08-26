# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-decision.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs)

run.mergedecision.classifiers <- function(df, cases = c(1000, 10000, nrow(df)/4,
                                                        nrow(df)/2, nrow(df))) {
  for (i in cases) {
    data <- prepare.data.mergedecision(df, i)
    results <- run.classifiers.mergedecision(merge.decision.model, data$train,
                                         data$test, i)
    cvResult <- cross.validation(merge.decision.model,
                                 run.classifiers.mergedecision,
                                 prepare.data.mergedecision, df, i, 10)
    write.csv(cvResult, file = sprintf("merge-decision-cv-%i.csv", i))
    cross.validation.plot(cvResult,
                          sprintf("Merge decision task (%d items)", i),
                          sprintf("merge-decision-cv-%i.pdf", i))
  }
}

run.mergedecision.classifiers(all)
