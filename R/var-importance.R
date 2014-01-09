#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

# Variable importance with random forests calculator for 
# the merge-time and merge-decision experiments

rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")
source(file = "R/classification.R")
source(file = "R/merge-time.R")
source(file = "R/merge-decision.R")

library(ggplot2)
library(doMC)
registerDoMC(num.processes)

rf.varimp <- function(model, sampler, data, num_samples = 5000, runs = 50) {

  result <- foreach(n=1:runs, .combine=rbind) %dopar% {
    df <- sampler(data, num_samples)
    rfmodel <- randomForest(model, data=df$train, importance = T,
                            type = "classification", mtry = 5,
                            ntree = 2000)
    print(importance(rfmodel))
    i <- data.frame(importance(rfmodel))
    i$var <- row.names(i)
    i$var <- as.factor(i$var)
    i$run <- n
    i
  }

  result = aggregate(. ~ var, data = result, mean)
  result = result[with(result, order(-MeanDecreaseAccuracy)),]
  result[c('var', 'MeanDecreaseAccuracy')]
}

run.rf.varimp <- function(expname, model, sampler, data, smpl_size, runs) {
  varimp <- rf.varimp(model, sampler, data, smpl_size, runs)
  name.for.file <- gsub(" ", "-", tolower(expname))
  chart.title = sprintf("%s variable importance\n(n = %d, ntree = 2000, mtry = 5, runs = %d)",
                        expname, smpl_size, runs)

  p <- ggplot(varimp, aes(y = reorder(MeanDecreaseAccuracy, var), x = MeanDecreaseAccuracy)) +
    geom_point(size = 3) +
    scale_y_discrete("Variable", label = rev(varimp$var)) +
    xlab("Mean Decrease in Accuracy") +
    ggtitle(chart.title)

  store.pdf(p, plot.location, sprintf("varimp-%s-%d-%d.pdf", name.for.file, smpl_size, runs))
  print(varimp)
}

# Loading data files in a single dataframe
all <- load.data(project.list)

run.rf.varimp("Merge decision", merge.decision.model, prepare.data.mergedecision, all, floor(nrow(all)/2), 50)
run.rf.varimp("Merge time (3 classes)", merge.time.model, prepare.data.mergetime.3bins, all, floor(nrow(all)/2), 50)
