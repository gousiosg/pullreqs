# Shared functions for the classification experiments

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")

library(ROCR) 

# Get a project with the appropriate fields by name to run through a classification task
class.project <- function(dfs, name) {
  prepare.project.df(get.project(dfs, name))
}

# Strip a project data frame from unused columns
prepare.project.df <- function(a) {
  a[,c(7:25)]
}

# Run a cross validation round, return a dataframe with all results added
# sampler is f: data.frame -> Int -> list
# classifier is f: data.frame -> Int -> list
cross.validation <- function(model, classifier, sampler, df, num_samples, num_runs = 10) {
  result = lapply(c(1:num_runs),
                  function(n) {
                    dataset <- sampler(df, num_samples)
                    print(sprintf("Prior propability: %f", nrow(subset(dataset$train, merged == TRUE))/nrow(dataset$train)))
                    interm = classifier(model, dataset$train, dataset$test)
                    interm$run <- n
                    interm
                  })
  result = merge.dataframes(result)
  
  # Somewhere along the way, numbers are converted to characters. 
  # Too busy to investigate why
  result$auc <- as.numeric(result$auc)
  result$acc <- as.numeric(result$acc)
  result$prec <- as.numeric(result$prec)
  result$rec <- as.numeric(result$rec)
  result
}

# Extract classification metrics from a ROCR prediction object
classification.perf.metrics <- function(classif, pred.obj) {
  p1 <- performance(pred.obj, "acc")
  p2 <- performance(pred.obj, "prec", "rec")
  result = list(classifier = classif,
                auc  = as.numeric(performance(pred.obj,"auc")@y.values),
                acc  = median(Filter(function(x){is.finite(x)}, unlist(p1@y.values))),
                prec = median(Filter(function(x){is.finite(x)}, unlist(p2@y.values))),
                rec  = median(Filter(function(x){is.finite(x)}, unlist(p2@x.values))))
  print(sprintf("%s: AUC %f, ACC %f, PREC %f, REC %f", result$classif, result$auc, result$acc,
                result$prec, result$rec))
  result
}

# Calculate mean results after cross validation runs
cross.validation.means <- function(cvResult) {
  aggregate(. ~ classifier, data = cvResult, mean)
}

cross.validation.plot <- function(cvResult, metric) {
  ggplot(cvResult, aes(x = run, y = metric, colour = classifier)) + geom_line(size = 1)
}

rf.varimp <- function(model, sampler, data, num_samples = 5000, runs = 50) {
  result = lapply(c(1:runs), 
                  function(n) {
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
                  })
  result = merge.dataframes(result)
  result = aggregate(. ~ var, data = result, mean)
  result = result[with(result, order(-MeanDecreaseAccuracy)),]
  result[c('var', 'MeanDecreaseAccuracy')]
}
