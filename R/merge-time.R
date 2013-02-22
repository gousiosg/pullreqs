# Predicting merge_time of pull requests

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

# Include libs and helper scripts
library(ROCR)
library(randomForest)
library(e1071) # naiveBayes
library(pls)
library(Hmisc) # cut2

# Returns a list l with
# l[1] training dataset
# l[2] testing dataset
prepare.data.mergetime <- function(df, num_samples) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)

  # sample filter pull-requests that have not been merged
  a <- a[a$merged == "TRUE", ]

  if (num_samples >= nrow(a)) {
    num_samples = nrow(a) - 1
  }

  # binning - add column to classify requests into short/long
  #hist(log(aMerged$lifetime_minutes))
  bins <- 2
  # meanMergeTime <- median(a$mergetime_minutes)
  # a["merged_fast"] <- a$mergetime_minutes <= meanMergeTime
  # a$merged_fast <- as.factor(a$merged_fast)
  a$merged_fast <- cut2(a$mergetime_minutes, g=bins)

  a <- a[sample(nrow(a), size=num_samples), ]

  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.90), ]
  a.test <- a[(floor(nrow(a)*.90)+1):nrow(a), ]
  list(train=a.train, test=a.test)
}

# Bining to 1 hour, 1 day, 1 week and rest
prepare.data.mergetime.4bins <- function(df, num_samples) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)

  # sample filter pull-requests that have not been merged
  a <- a[a$merged == "TRUE", ]

  if (num_samples >= nrow(a)) {
    num_samples = nrow(a) - 1
  }

  a$merged_fast <- cut2(a$mergetime_minutes, c(60, 1440, 10080))
  a <- a[sample(nrow(a), size=num_samples), ]
  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.90), ]
  a.test <- a[(floor(nrow(a)*.90)+1):nrow(a), ]
  list(train=a.train, test=a.test)
}

# Returns a dataframe with the AUC, PREC, REC values per classifier
# Plots classification ROC curves
run.classifiers.mergetime <- function(model, train, test, uniq = "") {
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
  pred.obj <- prediction(predictions[,2], test$merged_fast)
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
  print(svmmodel)

  predictions <- predict(svmmodel, newdata=test, type="prob", probability=TRUE)
  pred.obj <- prediction(attr(predictions, "probabilities")[,2], test$merged_fast)
  metrics <- classification.perf.metrics("svm", pred.obj)
  results[2,] <- c("svm", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  svmperf <- performance(pred.obj, "tpr","fpr")
  
  #
  ### Binary logistic regression
  logmodel <- glm(model, data=train, family = binomial(logit));
  print(logmodel)

  predictions <- predict(logmodel, newdata=test)
  pred.obj <- prediction(predictions, test$merged_fast)
  metrics <- classification.perf.metrics("binlogregr", pred.obj)
  results[3,] <- c("binlogregr", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  logperf <- performance(pred.obj, "tpr","fpr")

  #
  ### Naive Bayes
  bayesModel <- naiveBayes(model, data = train)
  print(bayesModel)

  predictions <- predict(bayesModel, newdata=test, type="raw")
  pred.obj <- prediction(predictions[,2], test$merged_fast)
  metrics <- classification.perf.metrics("naive bayes", pred.obj)
  results[4,] <- c("naive bayes", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  bayesperf <- performance(pred.obj, "tpr","fpr")
  
  # Plot classification performance
  pdf(file=sprintf("%s/%s-%s.pdf", plot.location, "classif-perf-merge-time", uniq))
  plot (rfperf, col = 1, main = "Classifier performance for pull request merge time")
  plot (svmperf, col = 2, add = TRUE)
  plot (logperf, col = 3, add = TRUE)
  plot (bayesperf, col = 4, add = TRUE)
  legend(0.6, 0.6, c('random forest', 'svm', 'binlog regression', 'naive bayes', sprintf("n=%d",sample_size)), 1:5)
  dev.off()

  results
}

merge.time.model = merged_fast ~ team_size + num_commits + files_changed + 
  perc_external_contribs + sloc + src_churn + test_churn + 
  commits_on_files_touched +  test_lines_per_1000_lines + prev_pullreqs +  
  requester_succ_rate + main_team_member + num_comments

#
### Linear regression model
#a <- a[a$mergetime_minutes > 0, ]
#a["log_mergetime"] <- log(a$mergetime_minutes)

# stepwise linear regression
#lmmodel <- lm(log_mergetime ~ sloc + test_lines_per_1000_lines + num_commits + src_churn + test_churn + files_changed + 
#  perc_external_contribs + requester_succ_rate + team_size + prev_pullreqs + commits_on_files_touched, data=a);
#step <- stepAIC(lmmodel, direction="both")
#step$anova # display results 
#summary(step$model)

# PCA analysis to extract the components

# model of stepwise regression
#lmmmodel <- lm(log_mergetime ~ src_churn + test_churn + files_changed + perc_external_contribs + 
#  requester_succ_rate + team_size + prev_pullreqs + commits_on_files_touched, data = a)
#summary(lmmodel)

# 10 fold cross validation on the training data
#library(DAAG)
#results <- cv.lm(df=a, lmmodel, m=10)
#cor(a$log_mergetime, results$Predicted)**2
#cor(a$log_mergetime, results$cvpred)**2

# k <- 5
# folds <- cvsegments(nrow(a), k)
# result <- c()
# for (fold in 1:k){
#   currentFold <- folds[fold][[1]]
#   train <- a[-currentFold,]
#   test <- a[currentFold,]
#   svmmodel = svm(merged_fast~. - mergetime_minutes - requester, data=train)
#   pred = predict(svmmodel, test)
#   result <- c(result, (table(pred, test$merged_fast)))
# }
#print(results)
#print(svmmodel)
#summary(svmmodel)
#plot(svmmodel, data=a)
