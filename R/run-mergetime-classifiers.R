#
# Merge time classifiers
# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-time.R")

library(doMC)
registerDoMC(num.processes)

# Loading data files
all <- load.data()
#all <- load.some(dir=data.file.location, pattern="*.csv$", 10)

run.mergetime.classifiers <- function(df, cases = c(1000, 10000,
                                                    floor(nrow(df)/4),
                                                    floor(nrow(df)/2),
                                                    nrow(df)),
                                      bins = 3, suffix = "") {
  splitter <- get(sprintf("prepare.data.mergetime.%dbins", bins))
  for (i in cases) {
    cvResult <- cross.validation(merge.time.model,
                                 run.classifiers.mergetime,
                                 splitter, df, i, 10)
    write.csv(cvResult, file = sprintf("merge-time-cv-%dbins-%d%s.csv", bins, i, suffix))
    cross.validation.plot(cvResult,
                          sprintf("Merge time task cross validation (%d classes, %d items)",bins, i),
                          sprintf("merge-time-cv-%dbins-%d%s.pdf",bins, i, suffix))
  }
}

run.mergetime.classifiers(all)
#run.mergetime.classifiers(all, c(1000))

# Redefine the merge time model with the dominant characteristics and rerun
merge.time.model = merge_time ~ requester_succ_rate + sloc + test_lines_per_kloc + prev_pullreqs + perc_external_contribs + src_churn
run.mergetime.classifiers(all, suffix = "-dominant")