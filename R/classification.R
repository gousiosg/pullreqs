source(file = "R/variables.R")
source(file = "R/utils.R")
library(ROCR) 
library(rpart)
library(randomForest)
library(cvTools)

source(file = "R/variables.R")
source(file = "R/utils.R")

# Get a project with the appropriate fields by name to run through a classification task
class.project <- function(dfs, name) {
  prepare.project.df(get.project(dfs, name))
}

# Strip a project data frame from unused columns
prepare.project.df <- function(a) {
  a[,c(7:25)]
}

classification.perf.metrics <- function(classif, pred.obj) {
  p1 <- performance(pred.obj, "acc")
  p2 <- performance(pred.obj, "prec", "rec")
  result = list(classifier = classif,
                auc  = as.numeric(performance(pred.obj,"auc")@y.values),
                acc  = median(Filter(function(x){is.finite(x)}, unlist(p1@y.values))),
                prec = median(Filter(function(x){is.finite(x)}, unlist(p2@y.values))),
                rec  = median(Filter(function(x){is.finite(x)}, unlist(p2@x.values))))
  print(sprintf("%s: AUC %f, ACC %f, PREC %f, REC %f", result$classif, result$auc, result$acc,
                result$prec, result$rec))
  result
}

find.file.err <- function() {
  for (file in list.files(data.file.location, pattern="*.csv$", full.names = T)) { 
    data <- read.csv(pipe(paste("cut -f2-25 -d',' ", file)))
    data <- addcol.merged.df(data)
    a <- prepare.project.df(data)
  
    # split data into training and test data
    a.train <- a[1:floor(nrow(a)*.75), ]
    a.test <- a[(floor(nrow(a)*.75)+1):nrow(a), ]
  
    print(a.train)
    rfmodel <- randomForest(merged~. - num_comments 
                            - requester - watchers - followers, 
                            data=a.train, importance = T)
  }
}

kfolds <- function(df, numruns) {

  lapply(cvFolds(NROW(df), K=numruns),
         function(x) {
           train <- df[folds$subsets[folds$which != i], ]
           validation <- df[folds$subsets[folds$which == i], ]
           print(sprintf("sizes: train: %d, validation: %d", length(train), length(validation)))
           result = c(result, list(train=train, validation=validation))
         })
}