rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(caret)
library(doMC)
registerDoMC(cores = 3)

# This will load the data.table all in the global environment
source(file = "R/data-preparation.R")

#all.1 <- data.frame(all)
#all <- data.frame(all.1)
#all <- all[sample(nrow(all.1), 50000), ]

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

# This removes highly correlated features from the tested model
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

# Determine best settings for each classifier
fitControl <- trainControl(
  method = "repeatedcv",
  number = 5,
  repeats = 1, 
  classProbs = T,
  allowParallel = T,
  verboseIter = T,
  summaryFunction = twoClassSummary)

# Some learners have trouble to handle TRUE/FALSE as factor level names
all$merged <- apply(all, 1, function(x){if (!is.na(x[6])) {
  'merged'
} else {
  'unmerged'
}})

all$merged <- as.factor(all$merged)

train.test <- function(model, fitControl, method, train, test) {
  trained <-  train(model, data = train,
                    method = method,
                    trControl = fitControl,
                    metric = "ROC")
  pred <- predict(trained, test)
  varImp <- tryCatch({
    v = varImp(trained, scale = T)
    pdf(sprintf("varimp-%s-%d.pdf", method, nrow(train)))
    plot(v)
    dev.off()
    v
    }, error=function(){return(NA)})
  list(varImp,
       results = confusionMatrix(pred, test$merged),
       method = method)
}

set.seed(998)

# Split in training/testing
inTraining <- createDataPartition(all$merged, p = .75, list = FALSE)
training <- all[ inTraining,]
testing  <- all[-inTraining,]

methods <- c('glm', "rf", 'AdaBoost.M1', 'svmLinear', 'svmRadial', 'avNNet', 'dnn')

# Balance the dataset with the downsample method
down_sampled <- downSample(x = all[, -which(names(all) %in% c("merged"))],
                           y = all$merged)
down_sampled <- rename(down_sampled, c("Class" = "merged"))

results.down_sampled <- Map(function(m) {
  train.test(merge.decision.model, fitControl, m, down_sampled, testing)
}, methods)

# No balancing
results.full <- Map(function(m) {
  train.test(merge.decision.model, fitControl, m, down_sampled, testing)
}, methods)

# Other, smarter balancing methods. They do not scale.
# SMOTE is too slow and does not scale
# smote_train <- SMOTE(merge.decision.model, data = training)
#table(smote_train$merged)

# rose_train <- ROSE(merge.decision.model, data = training)$data
# table(rose_train$merged)
