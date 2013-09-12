# Shared functions for the classification experiments

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")

library(ROCR)
library(randomForest)
library(e1071)
library(nnet)
library(reshape)
library(ggplot2)
library(foreach)

# Get a project with the appropriate fields by name to run through a classification task
class.project <- function(dfs, name) {
  prepare.project.df(get.project(dfs, name))
}

# Strip a project data frame from unused columns
prepare.project.df <- function(a) {
  a[,c(7:33)]
}

rf.train <- function(model, train.set) {
  rfmodel <- randomForest(model, data=train.set, importance = T)
  print(rfmodel)
  print(importance(rfmodel))
  varImpPlot(rfmodel, type=1)
  varImpPlot(rfmodel, type=2)
  plot(rfmodel)
  rfmodel
}

svm.train <- function(model, train.set) {
  tobj <- tune.svm(model, data=train.set[1:500, ], gamma = 10^(-6:-3), cost = 10^(1:2))
  summary(tobj)
  bestGamma <- tobj$best.parameters[[1]]
  bestCost <- tobj$best.parameters[[2]]
  svmmodel <- svm(model, data=train, gamma=bestGamma, cost = bestCost, probability=TRUE)
  print(summary(svmmodel))
  svmmodel
}

binlog.train <- function(model, train.set) {
  binlog <- glm(model, data=train.set, family = binomial(logit));
  print(summary(binlog))
  binlog
}

multinom.train <- function(model, train.set) {
  trained <- multinom(model, train.set)
  #print(summary(trained))
  trained
}

bayes.train <- function(model, train.set) {
  bayesModel <- naiveBayes(model, data = train.set)
  print(summary(bayesModel))
  print(bayesModel)
  bayesModel
}

# Run a cross validation round, return a dataframe with all results added
# sampler is f: data.frame -> Int -> list
# classifier is f: data.frame -> Int -> list
cross.validation <- function(model, classifier, sampler, df, num_samples, num_runs = 10) {
  result <- foreach(n=1:num_runs, .combine=rbind) %dopar% {
              dataset <- sampler(df, num_samples)
              printf("Running cross.val num_samples: %d, run: %d", num_samples,
                     n)
              interm <- classifier(model, dataset$train, dataset$test)
              interm$run <- n
              interm
  }
  
  # Somewhere along the way, numbers are converted to characters. 
  # Too busy to investigate why
  result$auc <- as.numeric(result$auc)
  result$acc <- as.numeric(result$acc)
  #result$prec <- as.numeric(result$prec)
  #result$rec <- as.numeric(result$rec)
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

# Plot classifier performance accross cross validation runs for the metrics
# returned by cross.validation
cross.validation.plot <- function(cvResult, title = "" ,fname = "cv.pdf") {
  cvResult <- melt(cvResult, id=c('classifier', 'run'))
  cvResult$value <- as.numeric(cvResult$value)
  p <- ggplot(cvResult, aes(x = run, y = value, colour = classifier)) +
    geom_line(size = 1) + facet_wrap(~variable) + labs(title =title)
  store.pdf(p, plot.location, fname)
}

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
