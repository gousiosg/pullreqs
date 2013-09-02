# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-decision.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs,200)

run.mergedecision.classifiers <- function(df, cases = c(1000, 10000,
                                                        floor(nrow(df)/4),
                                                        floor(nrow(df)/2),
                                                        nrow(df))) {
  for (i in cases) {
    cvResult <- cross.validation(merge.decision.model,
                                 run.classifiers.mergedecision,
                                 prepare.data.mergedecision, df, i, 10)
    write.csv(cvResult, file = sprintf("merge-decision-cv-%d.csv", i))
    cross.validation.plot(cvResult,
                          sprintf("Merge decision task cross validation (%d items)", i),
                          sprintf("merge-decision-cv-%d.pdf", i))
  }
}

run.mergedecision.classifiers(all)
# run.mergedecision.classifiers(all, c(1000))
