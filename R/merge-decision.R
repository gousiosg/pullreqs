# Predicting whether pull requests will be merged

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

# Include libs and helper scripts
library(ROCR) 
library(randomForest)
library(e1071)

merge.decision.model <- merged ~ team_size + num_commits + files_changed +
  perc_external_contribs + sloc + src_churn + test_churn +
  commits_on_files_touched +  test_lines_per_kloc + prev_pullreqs +
  requester_succ_rate + main_team_member

# Returns a list l where 
# l[1] training dataset
# l[2] testing dataset
prepare.data.mergedecision <- function(df, num_samples) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)

  if (num_samples >= nrow(a)) {
    num_samples = nrow(a) - 1
  }

  # Take sample
  a <- a[sample(nrow(a), size=num_samples), ]

  # Remove column mergetime_minutes as it contains NAs
  a <- a[-c(1)]

  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.90), ]
  a.test <- a[(floor(nrow(a)*.90)+1):nrow(a), ]
  list(train=a.train, test=a.test)
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

bayes.train <- function(model, train.set) {
  bayesModel <- naiveBayes(model, data = train.set)
  print(summary(bayesModel))
  print(bayesModel)
  bayesModel
}

# Returns a dataframe with the AUC, PREC, REC values per classifier
# Plots classification ROC curves
run.classifiers.mergedecision <- function(model, train, test, uniq = "") {
  print(sprintf("Prior propability: %f", nrow(subset(data$train, merged == TRUE))/nrow(data$train)))
  sample_size = nrow(train) + nrow(test)
  results = data.frame(classifier = rep(NA, 4), auc = rep(0, 4), acc = rep(0,4),
                       prec = rep(0, 4), rec = rep(0, 4), stringsAsFactors=FALSE)
  #
  ### Random Forest
  rfmodel <- rf.train(model, train)
  predictions <- predict(rfmodel, test, type="prob")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("randomforest", pred.obj)
  results[1,] <- c("randomforest", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  rfperf <- performance(pred.obj, "tpr","fpr")
  

  #
  ### SVM
#   svmmodel <-  svm.train(train)
# 
#   predictions <- predict(svmmodel, newdata=test, type="prob", probability=TRUE)
#   pred.obj <- prediction(attr(predictions, "probabilities")[,2], test$merged)
#   metrics <- classification.perf.metrics("svm", pred.obj)
#   results[2,] <- c("svm", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
#   svmperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### Binary logistic regression
  logmodel <- binlog.train(model, train)

  predictions <- predict(logmodel, newdata=test)
  pred.obj <- prediction(predictions, test$merged)
  metrics <- classification.perf.metrics("binlogreg", pred.obj)
  results[3,] <- c("binlogregr", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  logperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### Naive Bayes
  bayesModel <- bayes.train(model, train)

  predictions <- predict(bayesModel, newdata=test, type="raw")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("naive bayes", pred.obj)
  results[4,] <- c("naive bayes", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  bayesperf <- performance(pred.obj, "tpr","fpr")
  
  # Plot classification performance
  pdf(file=sprintf("%s/%s-%s.pdf", plot.location, "classif-perf-merge-decision", uniq))
  plot (rfperf, col = 1, main = "Classifier performance for pull request merge decision")
#   plot (svmperf, col = 2, add = TRUE)
  plot (logperf, col = 3, add = TRUE)
  plot (bayesperf, col = 4, add = TRUE)
  legend(0.6, 0.6, c('random forest', 'svm', 'binlog regression', 'naive bayes'), 1:5, title = sprintf("n=%d",sample_size))
  dev.off()
  
  results
}

merge.decision.missclassif.rate <- function(# Response variable and predictors
                                            formula,
                                            # A dataframe with all data
                                            df = data.frame(),
                                            # Number of rows to use for training
                                            train.size = nrow(df)/2) {
  data <- prepare.data.mergedecision(df, train.size)
  rfmodel <- rf.train(formula, data$train)
  projects <- unique(df$project_name)
  print(projects)
  class.metrics <- lapply(projects, function(project) {
    project.data <- subset(df, project_name == project)
    pred.response <- predict(rfmodel, project.data, type = "response")
    rf.result = data.frame(actual = project.data$merged, predicted = pred.response)
    rf.result$correct <- rf.result$actual == rf.result$predicted
    err = nrow(subset(rf.result, correct == FALSE)) / nrow(rf.result)
    printf("Project: %s, Error rate: %f", project, err)
    data.frame(project=c(project), err=c(err))
  })
  merge.dataframes(class.metrics)
}
