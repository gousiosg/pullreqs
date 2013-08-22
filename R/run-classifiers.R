# Run all classification experiments in one go

#
# Merge time classifiers 2 bins
# Clean up workspace
rm(list = ls(all = TRUE))

source(file = "R/merge-time.R")

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs, 200)

#n = 1000
data <- prepare.data.mergetime(all, 1000)
results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "1k")
cvResult1k <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime, all, 1000, 10)
write.csv(cvResult1k, file = "merge-time-cv-1k.csv")

#n = 10000
data <- prepare.data.mergetime(all, 10000)
results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "10k")
cvResult10k <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime, all, 10000, 10)
write.csv(cvResult10k, file = "merge-time-cv-10k.csv")

#n = all rows
data <- prepare.data.mergetime(all, nrow(all))
results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "all")
cvResultAll <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime, all, nrow(all), 10)
write.csv(cvResultAll, file = "merge-time-cv-all.csv")

# Merge decision classifiers

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

#
# Merge time classifiers -- 4 bins
# Clean up workspace
# rm(list = ls(all = TRUE))
# #
# source(file = "R/merge-time.R")
# 
# # Loading data files
# dfs <- load.all(dir=data.file.location, pattern="*.csv$")
# dfs <- addcol.merged(dfs)
# all <- merge.dataframes(dfs)
# 
# #n = 1000
# data <- prepare.data.mergetime.4bins(all, 1000)
# results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "1k")
# cvResult1k <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime.4bins , all, 1000, 10)
# write.csv(cvResult1k, file = "merge-time-4bins-cv-1k.csv")
# 
# #n = 10000
# data <- prepare.data.mergetime.4bins(all, 10000)
# results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "10k")
# cvResult10k <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime.4bins , all, 10000, 10)
# write.csv(cvResult10k, file = "merge-time-4bins-cv-10k.csv")
# 
# #n = all rows
# data <- prepare.data.mergetime.4bins(all, nrow(all))
# results <- run.classifiers.mergetime(merge.time.model, data$train, data$test, "all")
# cvResultAll <- cross.validation(merge.time.model, run.classifiers.mergetime, prepare.data.mergetime.4bins , all, nrow(all), 10)
# write.csv(cvResultAll, file = "merge-time-4bins-cv-all.csv")

