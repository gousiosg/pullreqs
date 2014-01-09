#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/cmdline.R")
source(file = "R/merge-decision.R")

library(doMC)
registerDoMC(num.processes)

# Loading data files
all <- load.data(project.list)

run.mergedecision.classifiers <- function(df, cases = c(1000, 10000,
                                                        floor(nrow(df)/4),
                                                        floor(nrow(df)/2),
                                                        nrow(df)), 
                                          suffix = "") {
  for (i in cases) {
    cvResult <- cross.validation(merge.decision.model,
                                 run.classifiers.mergedecision,
                                 prepare.data.mergedecision, df, i, 10)
    write.csv(cvResult, file = sprintf("merge-decision-cv-%d%s.csv", i, suffix))
    cross.validation.plot(cvResult,
                          sprintf("Merge decision task cross validation (%d items)", i),
                          sprintf("merge-decision-cv-%d%s.pdf", i, suffix))
  }
}

run.mergedecision.classifiers(all)

# Redefine the merge decision model with the dominant characteristics and rerun
merge.decision.model = merged ~ sloc + test_lines_per_kloc + commits_on_files_touched
run.mergedecision.classifiers(all, suffix = "-dominant")
