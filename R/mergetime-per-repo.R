#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/cmdline.R")
source(file = "R/merge-time.R")

library(doMC)
registerDoMC(1)

all <- subset(load.data(project.list), merged==TRUE)

splitter <- get(sprintf("prepare.data.mergetime.%dbins", 4))
foobar <- Map (function(project) {
  data <- subset(all, project_name == project) 
  printf("Running for %s", project)
  result <- cross.validation(merge.time.model, run.classifiers.mergetime,
                             splitter, data, nrow(data), 1)

  result$project <- project
  result
}, unique(all$project_name)[c(5,6)])