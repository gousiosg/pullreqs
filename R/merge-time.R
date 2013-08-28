# Predicting merge_time of pull requests

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

library(pROC)
library(sqldf)

merge.time.model = merge_time ~ team_size + files_changed +
  perc_external_contribs + sloc + src_churn + test_churn +
  commits_on_files_touched +  test_lines_per_kloc + prev_pullreqs +
  requester_succ_rate + main_team_member + conflict + forward_links

prepare.data.mergetime <- function(df, num_samples = nrow(df),
                                   bins = c(0, mean(df$mergetime_minutes), max(df$mergetime_minutes)),
                                   labels = c('FAST', 'SLOW')) {
  # Prepare the data for prediction
  a <- prepare.project.df(df)

  # sample filter pull-requests that have not been merged
  a <- subset(a, merged == TRUE)

  if (num_samples >= nrow(a)) {
    num_samples = nrow(a) - 1
  }

  a$merge_time <- cut(a$mergetime_minutes, breaks = bins, labels = labels,
                      ordered_result = T)

  a <- a[sample(nrow(a), size=num_samples), ]
  # split data into training and test data
  a.train <- a[1:floor(nrow(a)*.90), ]
  a.test <- a[(floor(nrow(a)*.90)+1):nrow(a), ]
  list(train=a.train, test=a.test)
}

# Bining to 1 hour, 1 day and rest
prepare.data.mergetime.3bins <- function(df, num_samples = nrow(df)) {
  merged <- subset(df, merged == T)
  prepare.data.mergetime(merged, num_samples,
                         c(-1,60,1440,max(merged$mergetime_minutes) + 1),
                         c('HOUR', 'DAY', 'REST'))
}

# Bining to 1 hour, 1 day, 1 week and rest
prepare.data.mergetime.4bins <- function(df, num_samples = nrow(df)) {
  merged <- subset(df, merged == T)
  prepare.data.mergetime(merged, num_samples,
                         c(-1,60,1440,10080,max(merged$mergetime_minutes) + 1),
                         c('HOUR', 'DAY', 'WEEK', 'REST'))
}

# Bining to fast and slow based on media time
prepare.data.mergetime.4bins <- function(df, num_samples = nrow(df)) {
  merged <- subset(df, merged == T)
  prepare.data.mergetime(merged, num_samples)
}

format.results <- function(name, test, predictions) {
  metrics = data.frame(actual = test$merge_time, 
                       predicted = as.ordered(predictions))
  if (length(levels(metrics$actual)) == length(levels(metrics$predicted))) {
    metrics$correct <- metrics$actual == metrics$predicted
    metric.stats <- sqldf("select a.actual, a.incor, b.cor, b.cor * 1.0/(a.incor + b.cor) as accuracy from (select actual, count(*) as incor from metrics m where correct = 0 group by actual) a, (select actual, count(*) as cor from metrics m where correct = 1 group by actual) b where a.actual = b.actual")
    roc <- multiclass.roc(predictions, test$merge_time)
    auc <- as.numeric(roc$auc)
    printf("%s auc: %f, acc: %f", name, auc, mean(metric.stats$accuracy))
    c(name, auc, mean(metric.stats$accuracy))
  } else {
    printf("%s failed to classify all levels", name)
    # Classifier ailed to predict at least one item to some level
    c(name, 0, 0)
  }
}

# Returns a dataframe with the AUC, PREC, REC values per classifier
# Plots classification ROC curves
run.classifiers.mergetime <- function(model, train, test) {
  sample_size = nrow(train) + nrow(test)
  results = data.frame(classifier = rep(NA, 3), auc = rep(0, 3), acc = rep(0, 3),
                       stringsAsFactors=FALSE)
  #
  ### Random Forest
  rfmodel <- rf.train(model, train)
  predictions <- predict(rfmodel, test, type="response")
  results[1,] <- format.results("randomforest", test, predictions)

  #
  ### Multinomial regression
  multinommodel <- multinom.train(model, train)
  predictions <- predict(multinommodel, test, type="class")
  results[2,] <- format.results("multinomregr", test, predictions)

  #
  ### Naive Bayes
  bayesModel <- bayes.train(model, train)
  predictions <- predict(bayesModel, test)
  results[3,] <- format.results("naivebayes", test, predictions)

  subset(results, auc > 0)
}

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

