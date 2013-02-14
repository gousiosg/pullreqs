# Predicting whether pull requests will be merged

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

# Include libs and helper scripts
library(ROCR) 
library(randomForest)
library(e1071)

# Returns a list l where 
# l[1] training dataset
# l[2] testing dataset
prepare.data.mergedecision <- function(df, num_samples) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)

  # Take sample
  a <- a[sample(nrow(a), size=num_samples), ]

  # Remove column mergetime_minutes as it contains NAs
  a <- a[-c(1)]

  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.75), ]
  a.test <- a[(floor(nrow(a)*.75)+1):nrow(a), ]
  list(train=a.train, test=a.test)
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
  rfmodel <- randomForest(model, data=train, importance = T)
  print(rfmodel)
  print(importance(rfmodel))
  varImpPlot(rfmodel, type=1)
  varImpPlot(rfmodel, type=2)
  plot(rfmodel)

  predictions <- predict(rfmodel, test, type="prob")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("randomforest", pred.obj)
  results[1,] <- c("randomforest", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  rfperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### SVM - first tune and then run it with 10-fold cross validation
  tobj <- tune.svm(model, data=train[1:500, ], gamma = 10^(-6:-3), cost = 10^(1:2))
  summary(tobj)
  bestGamma <- tobj$best.parameters[[1]]
  bestCost <- tobj$best.parameters[[2]]
  svmmodel <- svm(model, data=train, gamma=bestGamma, cost = bestCost, probability=TRUE)
  print(summary(svmmodel))

  predictions <- predict(svmmodel, newdata=test, type="prob", probability=TRUE)
  pred.obj <- prediction(attr(predictions, "probabilities")[,2], test$merged)
  metrics <- classification.perf.metrics("svm", pred.obj)
  results[2,] <- c("svm", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  svmperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### Binary logistic regression
  logmodel <- glm(model, data=train, family = binomial(logit));
  print(summary(logmodel))

  predictions <- predict(logmodel, newdata=test)
  pred.obj <- prediction(predictions, test$merged)
  metrics <- classification.perf.metrics("binlogreg", pred.obj)
  results[3,] <- c("binlogregr", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  logperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### Naive Bayes
  bayesModel <- naiveBayes(model, data = train)
  print(summary(bayesModel))
  print(bayesModel)

  predictions <- predict(bayesModel, newdata=test, type="raw")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("naive bayes", pred.obj)
  results[4,] <- c("naive bayes", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  bayesperf <- performance(pred.obj, "tpr","fpr")
  
  # Plot classification performance
  pdf(file=sprintf("%s/%s-%s.pdf", plot.location, "classif-perf-merge-time", uniq))
  plot (rfperf, col = 1, main = "Classifier performance for pull request merge decision")
  plot (svmperf, col = 2, add = TRUE)
  plot (logperf, col = 3, add = TRUE)
  plot (bayesperf, col = 4, add = TRUE)
  legend(0.6, 0.6, c('random forest', 'svm', 'binlog regression', 'naive bayes'), 1:5, title = sprintf("n=%d",sample_size))
  dev.off()
  
  results
}

merge.decision.model <- merged ~ team_size + num_commits + files_changed + 
  perc_external_contribs + sloc + src_churn + test_churn + 
  commits_on_files_touched +  test_lines_per_1000_lines + prev_pullreqs + 
  requester_succ_rate
