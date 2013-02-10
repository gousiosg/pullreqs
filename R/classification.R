source(file = "R/variables.R")
source(file = "R/utils.R")
library(ROCR) 
library(rpart)
library(randomForest)
library(cvTools)

rf <- function(formula, ds) {
  randomForest(formula, data=ds, importance = T)
}

ct <- function(ds, formula) {
  rpart(formula, data=train, method="class")
}

# from http://stats.stackexchange.com/questions/37411/calculating-precision-and-recall-in-r
prf <- function(predAct){
    ## predAct is two col dataframe of pred,act
    preds = predAct[,1]
    trues = predAct[,2]
    xTab <- table(preds, trues)
    clss <- as.character(sort(unique(preds)))
    r <- matrix(NA, ncol = 7, nrow = 1, 
        dimnames = list(c(),c('Acc',
        paste("P",clss[1],sep='_'), 
        paste("R",clss[1],sep='_'), 
        paste("F",clss[1],sep='_'), 
        paste("P",clss[2],sep='_'), 
        paste("R",clss[2],sep='_'), 
        paste("F",clss[2],sep='_'))))
    r[1,1] <- sum(xTab[1,1],xTab[2,2])/sum(xTab) # Accuracy
    r[1,2] <- xTab[1,1]/sum(xTab[,1]) # Miss Precision
    r[1,3] <- xTab[1,1]/sum(xTab[1,]) # Miss Recall
    r[1,4] <- (2*r[1,2]*r[1,3])/sum(r[1,2],r[1,3]) # Miss F
    r[1,5] <- xTab[2,2]/sum(xTab[,2]) # Hit Precision
    r[1,6] <- xTab[2,2]/sum(xTab[2,]) # Hit Recall
    r[1,7] <- (2*r[1,5]*r[1,6])/sum(r[1,5],r[1,6]) # Hit F
    r}

prf.rf <- function(formula, train, test, resp) {
  model <- rf(formula, train)
  pred <- predict (model, test)
  perf <- prf(data.frame(pred, resp)) 
}

# Get a project with the appropriate fields to run through a classification task
class.project <- function(dfs, name) {
  prepare.project.df(get.project(dfs, name))
}

# Strip a project data frame from unused columns
prepare.project.df <- function(a) {
  a$merged <- apply(a, 1, function(r){if(is.na(r[4])){F} else {T}})
  a$merged <- as.factor(a$merged)
  a <- a[,c(7:25)]
  a
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