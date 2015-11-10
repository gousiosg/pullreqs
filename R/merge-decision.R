#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

# Predicting whether pull requests will be merged

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

minority.class <- nrow(subset(all, all$merged == FALSE))
merge.decision.model <- merged ~ conflict + forward_links + intra_branch +
  description_length + num_commits_open + num_commit_comments_open + 
  files_added_open + files_deleted_open + files_modified_open +
  files_changed_open + src_files_open + doc_files_open + other_files_open +
  src_churn_open + test_churn_open + new_entropy + entropy_diff + 
  commits_on_files_touched + commits_to_hottest_file + hotness +
  at_mentions_description + perc_external_contribs + test_lines_per_kloc +
  test_cases_per_kloc + asserts_per_kloc + stars + team_size + workload +
  prev_pullreqs + requester_succ_rate + followers + main_team_member +
  social_connection + prior_interaction_comments +
  prior_interaction_events

# Returns a list l where 
# l[1] training dataset
# l[2] testing dataset
prepare.data.mergedecision <- function(df, num_samples) {
  if (num_samples >= nrow(df)) {
    num_samples = nrow(df) - 1
  }

  # Take sample
  df <- df[sample(nrow(df), size=num_samples), ]

  # Remove column mergetime_minutes as it contains NAs
  df <- df[-c(1)]

  # split data into training and test data
  df.train <- df[1:floor(nrow(df)*.90), ]
  df.test <- df[(floor(nrow(df)*.90)+1):nrow(df), ]
  list(train=df.train, test=df.test)
}

# Returns a dataframe with the AUC, PREC, REC values per classifier
# Plots classification ROC curves
run.classifiers.mergedecision <- function(model, train, test, uniq = "") {
  printf("Prior propability: %f", nrow(subset(train, merged == T))/nrow(train))
  sample_size = nrow(train) + nrow(test)
  results = data.frame(classifier = rep(NA, 3), auc = rep(0, 3), acc = rep(0,3),
                       prec = rep(0, 3), rec = rep(0, 3), stringsAsFactors=FALSE)
  #
  ### Random Forest
  rfmodel <- rf.train(model, train)
  predictions <- predict(rfmodel, test, type="prob")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("randomforest", pred.obj)
  results[1,] <- c("randomforest", metrics$auc, metrics$acc, metrics$prec, metrics$rec)

  #
  ### SVM
#   svmmodel <-  svm.train(train)
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
  
  #
  ### Naive Bayes
  bayesModel <- bayes.train(model, train)
  predictions <- predict(bayesModel, newdata=test, type="raw")
  pred.obj <- prediction(predictions[,2], test$merged)
  metrics <- classification.perf.metrics("naive bayes", pred.obj)
  results[4,] <- c("naive bayes", metrics$auc, metrics$acc, metrics$prec, metrics$rec)
  
  subset(results, auc > 0)
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
