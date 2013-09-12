# Predicting whether pull requests will be merged

source(file = "R/packages.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/classification.R")

merge.decision.model <- merged ~ team_size + num_commits + files_changed +
  perc_external_contribs + sloc + src_churn + test_churn + num_comments +
  commits_on_files_touched +  test_lines_per_kloc + prev_pullreqs +
  requester_succ_rate + main_team_member + conflict + forward_links + 
  num_participants

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
