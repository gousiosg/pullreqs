# Predicting merge_time of pull requests

# Include libs and helper scripts
library(ggplot2)
library(randomForest)
library(ROCR) 
library(stargazer)
library(randomForest)
library(e1071)
library(pls)
library(Hmisc) # cut2

source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/multiplots.R")
source(file = "R/classification.R")

print("Loading data files..")
dfs <- load.all(dir=data.file.location, pattern="*.csv$")

# Add derived columns
dfs <- addcol.merged(dfs)

# Merge all dataframes in a single dataframe
merged <- merge.dataframes(dfs)

# Prepare the data for prediction
a <- prepare.project.df(merged)

# sample filter pull-requests that have not been merged
a <- a[a$merged == "TRUE", ]
a <- a[sample(nrow(a), size=10000), ]

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

#
### Random Forest
#model <- randomForest(merged_fast~. - mergetime_minutes - requester - num_comments - watchers - followers - sloc, data=a, importance = T)
#rfmodel <- randomForest(mergedtime_minutes~. - merge_mergetime_minutes - num_comments - requester, data=a, importance = T)
rfmodel <- randomForest(merged_fast~. - mergetime_minutes - num_comments - requester - watchers - merged
                        - followers, data=a.train, importance = T)
print(rfmodel)
#summary(rfmodel)
varImpPlot(rfmodel, type=1)
varImpPlot(rfmodel, type=2)
plot(rfmodel)

# ROC AUC
predictions <- predict(rfmodel, a.test, type="prob")
pred.obj <- prediction(predictions[,2], a.test$merged_fast)
perf <- performance(pred.obj, "tpr","fpr")
plot (perf, main="ROC random forest", colorize = T)
as.numeric(performance(pred.obj,"auc")@y.values)

#
### SVM - first tune and then run it with 10-fold cross validation
tobj <- tune.svm(merged_fast~. - mergetime_minutes - num_comments - requester- watchers - followers - intra_branch - main_team_member, data=a[1:500, ], gamma = 10^(-6:-3), cost = 10^(1:2))
summary(tobj)
bestGamma <- tobj$best.parameters[[1]]
bestCost <- tobj$best.parameters[[2]]
svmmodel <- svm(merged_fast~. - mergetime_minutes - num_comments - requester- watchers - followers - intra_branch - main_team_member, data=a.train, gamma=bestGamma, cost = bestCost, cross=10, probability=TRUE)
summary(svmmodel)

# ROC AUC for SVM
predictions <- predict(svmmodel, newdata=a.test, type="prob", probability=TRUE)
pred.obj <- prediction(attr(predictions, "probabilities")[,2], a.test$merged_fast)
perf <- performance(pred.obj, "tpr","fpr")
plot (perf, main="ROC SVM", colorize = T)
as.numeric(performance(pred.obj,"auc")@y.values)

#
### Binary logistic regression
logmodel <- glm(merged_fast ~ sloc + test_lines_per_1000_lines + num_commits + src_churn + test_churn + files_changed + 
  perc_external_contribs + requester_succ_rate + team_size + prev_pullreqs + commits_on_files_touched, data=a.train, family = binomial(logit));
summary(logmodel)

predictions <- predict(logmodel, newdata=a.test)
pred.obj <- prediction(predictions, a.test$merged_fast)
perf <- performance(pred.obj, "tpr","fpr")
plot (perf, main="ROC Log Regression", colorize = T)
as.numeric(performance(pred.obj,"auc")@y.values)

# RP.perf <- performance(pred.obj, "rec","prec")
# plot (RP.perf, colorize = T)
# ROC.acc <- performance(pred.obj, "acc")
# plot (ROC.acc, colorize = T)

#
### Linear regression model
a <- a[a$mergetime_minutes > 0, ]
a["log_mergetime"] <- log(a$mergetime_minutes)

# stepwise linear regression
lmmodel <- lm(log_mergetime ~ sloc + test_lines_per_1000_lines + num_commits + src_churn + test_churn + files_changed + 
  perc_external_contribs + requester_succ_rate + team_size + prev_pullreqs + commits_on_files_touched, data=a);
step <- stepAIC(lmmodel, direction="both")
step$anova # display results 
summary(step$model)

# PCA analysis to extract the components

# model of stepwise regression
lmmmodel <- lm(log_mergetime ~ src_churn + test_churn + files_changed + perc_external_contribs + 
  requester_succ_rate + team_size + prev_pullreqs + commits_on_files_touched, data = a)
summary(lmmodel)

# 10 fold cross validation on the training data
library(DAAG)
results <- cv.lm(df=a, lmmodel, m=10)
cor(a$log_mergetime, results$Predicted)**2
cor(a$log_mergetime, results$cvpred)**2

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
