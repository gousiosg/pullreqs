rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(caret)
library(DMwR)
library(ROSE)
library(doMC)
registerDoMC(cores = 3)

# This will load the data.table all in the global environment
source(file = "R/data-preparation.R")

all.1 <- data.frame(all)
all <- all[sample(nrow(all.1), 50000), ]

set.seed(998)
inTraining <- createDataPartition(all$merged, p = .75, list = FALSE)
training <- all[ inTraining,]
testing  <- all[-inTraining,]

min.class <- nrow(subset(all, merged == "FALSE"))
rfmodel <- randomForest(merge.decision.model, data=all, do.trace=T, importance = T,
                        sampsize=c('TRUE' = 2*min.class, 'FALSE'= min.class), mtry=5, ntree = 200)

merge.decision.model.all <- merged ~ intra_branch +
  description_length + num_commits_open + num_commit_comments_open + 
  files_added_open + files_deleted_open + files_modified_open +
  files_changed_open + src_files_open + doc_files_open + other_files_open +
  src_churn_open + test_churn_open + new_entropy + entropy_diff + 
  commits_on_files_touched + commits_to_hottest_file + hotness +
  at_mentions_description + perc_external_contribs + test_lines_per_kloc +
  test_cases_per_kloc + asserts_per_kloc + team_size + workload +
  prev_pullreqs + requester_succ_rate + followers + main_team_member +
  social_connection + prior_interaction_comments +
  prior_interaction_events + has_ci

merge.decision.model <- merged ~ intra_branch +
  description_length + num_commits_open + num_commit_comments_open + 
  files_added_open + files_deleted_open +
  files_changed_open + doc_files_open + other_files_open +
  src_churn_open + test_churn_open + entropy_diff + 
  commits_to_hottest_file + hotness +
  at_mentions_description + perc_external_contribs + test_lines_per_kloc +
  test_cases_per_kloc + team_size + workload +
  prev_pullreqs + requester_succ_rate + followers + main_team_member +
  social_connection + prior_interaction_comments +
  has_ci

# SMOTE is too slow and does not scale
#smote_train <- SMOTE(merge.decision.model, data = training)
#table(smote_train$merged)

rose_train <- ROSE(merge.decision.model, data = training)$data
table(rose_train$merged)

down_sampled <- downSample(x = all[, -ncol(all)],
                           y = all$merged)
down_sampled <- rename(down_sampled, c("Class" = "merged"))

fitControl <- trainControl(
  method = "repeatedcv",
  number = 5,
  repeats = 1, 
#  classProbs = T,
  allowParallel = T,
  verboseIter = T)

# Try various methods to balance the dataset
rfFitDefault <- train(merge.decision.model, data = training,
                      method = "rf",
                      trControl = fitControl,
                      verbose = T, metric = "Kappa")
plot(varImp(rfFitDefault, scale = T), top = 20)
confusionMatrix(rfFitDefault)

# Try various methods to balance the dataset
rfFitDownSampled <- train(merge.decision.model, data = down_sampled,
                          method = "rf",
                          trControl = fitControl,
                          verbose = T, metric = "Kappa")
plot(varImp(rfFitDownSampled, scale = T), top = 20)
confusionMatrix(rfFitDownSampled)

# rfFitSmote <- train(merge.decision.model, data = smote_train,
#                       method = "rf",
#                       trControl = fitControl,
#                       verbose = T)
# plot(varImp(rfFitSmote, scale = T), top = 20)
# confusionMatrix(rfFitSmote)

# rfFitRose <- train(merge.decision.model, data = rose_train,
#                    method = "rf",
#                    trControl = fitControl,
#                    verbose = T)
# plot(varImp(rfFitRose, scale = T), top = 20)
# confusionMatrix(rfFitRose)

resampling_models <- list(original = rfFitDefault,
                          ROSE = rfFitRose)

resampling_test <- resamples(resampling_models)

test_roc <- function(model, data) {
  library(pROC)
  roc_obj <- roc(factor(data$merged, levels=c("FALSE", "TRUE"), ordered =T),
                 factor(predict(model, data), levels=c("FALSE", "TRUE"), ordered =T ))
  
  ci(roc_obj)
}

resampling_test <- lapply(resampling_models, test_roc, data = testing)
resampling_test <- lapply(resampling_test, as.vector)
resampling_test <- do.call("rbind", resampling_test)
colnames(resampling_test) <- c("lower", "ROC", "upper")
resampling_test <- as.data.frame(resampling_test)
resampling_test
summary(resampling_models, metric = "ROC")

