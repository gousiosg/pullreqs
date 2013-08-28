#
# Merge time classifiers 2 bins
# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-time.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs)

run.mergetime.classifiers <- function(df, cases = c(1000, 10000,
                                                    floor(nrow(df)/4),
                                                    floor(nrow(df)/2),
                                                    nrow(df)),
                                      bins = 3) {
  splitter <- get(sprintf("prepare.data.mergetime.%dbins", bins))
  for (i in cases) {
    cvResult <- cross.validation(merge.time.model,
                                 run.classifiers.mergetime,
                                 splitter, df, i, 5)
    write.csv(cvResult, file = sprintf("merge-time-cv-%dbins-%d.csv", bins, i))
    cross.validation.plot(cvResult,
                          sprintf("Merge time task cross validation (%d bins, %d items)",bins, i),
                          sprintf("merge-time-cv-%dbins-%d.pdf",bins, i))
  }
}

run.mergetime.classifiers(all)
run.mergetime.classifiers(all, c(20000))
