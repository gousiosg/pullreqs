# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-decision.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs)

#n = 1000
data <- prepare.data.mergedecision(all, 1000)
run.classifiers.mergedecision(merge.decision.model, data$train, data$test, "1k")
cvResult1k <- cross.validation(merge.decision.model, run.classifiers.mergedecision, prepare.data.mergedecision, all, 1000, 10)
write.csv(cvResult1k, file = "merge-decision-cv-1k.csv")

#n = 10000
data <- prepare.data.mergedecision(all, 10000)
results <- run.classifiers.mergedecision(merge.decision.model, data$train, data$test, "10k")
cvResult10k <- cross.validation(merge.decision.model, run.classifiers.mergedecision, prepare.data.mergedecision, all, 10000, 10)
write.csv(cvResult10k, file = "merge-decision-cv-10k.csv")

#n = all rows
data <- prepare.data.mergedecision(all, nrow(all))
results <- run.classifiers.mergedecision(merge.decision.model, data$train, data$test, "All")
cvResultAll <- cross.validation(merge.decision.model, run.classifiers.mergedecision, prepare.data.mergedecision, all, nrow(all), 10)
write.csv(cvResultAll, file = "merge-decision-cv-all.csv")
