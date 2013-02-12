# Predicting merge_time of pull requests

# Include libs and helper scripts
library(ggplot2)
library(randomForest)
library(ROCR) 
library(stargazer)
library(randomForest)
library(e1071) # naiveBayes
library(pls)
library(Hmisc) # cut2

source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/multiplots.R")
source(file = "R/classification.R")

# Returns a list l where 
# l[1] training dataset
# l[2] testing dataset
prepare.data.mergetime <- function(df, num_samples, filter_expr) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)
  
  # sample filter pull-requests that have not been merged
  a <- a[a$merged == "TRUE", ]
  a <- a[sample(nrow(a), size=num_samples), ]
  
  # binning - add column to classify requests into short/long
  #hist(log(aMerged$lifetime_minutes))
  bins <- 2
  # meanMergeTime <- median(a$mergetime_minutes)
  # a["merged_fast"] <- a$mergetime_minutes <= meanMergeTime
  # a$merged_fast <- as.factor(a$merged_fast)
  a$merged_fast <- cut2(a$mergetime_minutes, g=bins)
  
  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.75), ]
  a.test <- a[(floor(nrow(a)*.75)+1):nrow(a), ]
  list(train=a.train, test=a.test)
}

# Returns a dataframe with the AUC, PREC, REC values per classifier
# Plots classification ROC curves
run.classifiers.mergetime <- function(train, test, uniq = "") {
  sample_size = nrow(train) + nrow(test)
  results = data.frame(classifier = rep(NA, 4), auc = rep(0, 4), prec = rep(0, 4), 
                       rec = rep(0, 4), stringsAsFactors=FALSE)
  #
  ### Random Forest
  rfmodel <- randomForest(merged_fast~. - mergetime_minutes - num_comments - 
                            requester - watchers - merged - followers, 
                          data=train, importance = T)
  print(rfmodel)
  importance(rfmodel)
  varImpPlot(rfmodel, type=1)
  varImpPlot(rfmodel, type=2)
  plot(rfmodel)
  # Cross validation for variable selection, doesn't seem to work
  with(rfcv(data$train[c(2:10, 11, 14, 20)], data$train$merged_fast), plot(n.var, error.cv))
  
  # ROC AUC
  predictions <- predict(rfmodel, test, type="prob")
  pred.obj <- prediction(predictions[,2], test$merged_fast)
  rfperf <- performance(pred.obj, "tpr","fpr")
  print(sprintf("random forest AUC %f", as.numeric(performance(pred.obj,"auc")@y.values)))
  results[1,] <- c("randomforest", as.numeric(performance(pred.obj,"auc")@y.values), 0, 0)
  
  #
  ### SVM - first tune and then run it with 10-fold cross validation
  tobj <- tune.svm(merged_fast~. - mergetime_minutes - num_comments - requester - 
                     watchers - followers, 
                   data=train[1:500, ], gamma = 10^(-6:-3), cost = 10^(1:2))
  summary(tobj)
  bestGamma <- tobj$best.parameters[[1]]
  bestCost <- tobj$best.parameters[[2]]
  svmmodel <- svm(merged_fast~. - mergetime_minutes - num_comments - requester -
                    watchers - followers, 
                  data=train, gamma=bestGamma, cost = bestCost, cross=10, 
                  probability=TRUE)
  print(summary(svmmodel))
  
  # ROC AUC for SVM
  predictions <- predict(svmmodel, newdata=test, type="prob", probability=TRUE)
  pred.obj <- prediction(attr(predictions, "probabilities")[,2], test$merged_fast)
  svmperf <- performance(pred.obj, "tpr","fpr")
  print(sprintf("SVM AUC %f", as.numeric(performance(pred.obj,"auc")@y.values)))
  results[2,] <- c("svm", as.numeric(performance(pred.obj,"auc")@y.values), 0, 0)
  
  #
  ### Binary logistic regression
  logmodel <- glm(merged_fast ~ sloc + test_lines_per_1000_lines + num_commits +
                    src_churn + test_churn +  files_changed + 
                    perc_external_contribs + requester_succ_rate + team_size + 
                    prev_pullreqs + commits_on_files_touched, 
                  data=train, family = binomial(logit));
  print(summary(logmodel))
  
  # AUC for binary logistic regression 
  predictions <- predict(logmodel, newdata=test)
  pred.obj <- prediction(predictions, test$merged_fast)
  logperf <- performance(pred.obj, "tpr","fpr")
  print(sprintf("logistic regression AUC %f", as.numeric(performance(pred.obj,"auc")@y.values)))
  results[3,] <- c("binlogregr", as.numeric(performance(pred.obj,"auc")@y.values), 0, 0)

  #
  ### Naive Bayes
  bayesModel <- naiveBayes(merged_fast~. - mergetime_minutes - num_comments - requester - 
                             watchers - followers, data = train)
  print(summary(bayesModel))
  
  # AUC for naive bayes
  predictions <- predict(bayesModel, newdata=test, type="raw")
  pred.obj <- prediction(predictions[,2], test$merged_fast)
  bayesperf <- performance(pred.obj, "tpr","fpr")
  print(sprintf("Naive Bayes AUC %f", as.numeric(performance(pred.obj,"auc")@y.values)))
  results[4,] <- c("naivebayes", as.numeric(performance(pred.obj,"auc")@y.values), 0, 0)
  
  # Plot classification performance
  pdf(file=sprintf("%s/%s-%s.pdf", plot.location, "classif-perf-merge-time", uniq))
  plot (rfperf, col = 1, main = "Classifier performance for pull request merge time")
  plot (svmperf, col = 2, add = TRUE)
  plot (logperf, col = 3, add = TRUE)
  plot (bayesperf, col = 4, add = TRUE)
  legend(0.6, 0.6, c('random forest', 'svm', 'logistic regression', 'naive bayes', sprintf("n=%d",sample_size)), 1:5)
  dev.off()

  results
}

# Loading data files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")

# Add derived columns
dfs <- addcol.merged(dfs)

# Merge all dataframes in a single dataframe
merged <- merge.dataframes(dfs)

#n = 1000
data <- prepare.data.mergetime(merged, 1000)
results <- run.classifiers.mergetime(data$train, data$test, "1k-full")

#n = 10000
data <- prepare.data.mergetime(merged, 10000)
results <- run.classifiers.mergetime(data$train, data$test, "10k-full")

#n = all rows
data <- prepare.data.mergetime(merged, nrow(merged))
results <- run.classifiers.mergetime(data$train, data$test, "all-full")

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
