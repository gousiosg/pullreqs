library(reshape)
library(ggplot2)

a <- read.csv("~/Desktop/growth.csv")
a$date <- as.Date(a$date, "%Y-%m-%d")
#a$sumcreates <- cumsum(a$creates)
#a$sumpushes <- cumsum(a$pushes)
#a$date <- as.Date(a$date, "%Y-%m-%d")
#b <- subset(a, select=c(date, sumpushes, sumcreates))

a <- subset(a, select=c(date, pushes, creates))
b <- melt(a, id = c('date'))

#p <- ggplot(b, aes(date, value, fill = variable, colour = variable)) + geom_area() + stat_ecdf()
p <- ggplot(b, aes(date, value, fill = variable, colour = variable)) + geom_abline() + scale_x_date(labels = date_format("%m"))

store.pdf(p, "~/Desktop/", "github-growth.pdf")

b <- with(a, a$merged <- function(r){if(is.na(r[4])){0} else {1}})

source(file = "R/variables.R")
source(file = "R/utils.R")
library(ROCR) 
dfs <- load.all(dir=data.file.location)
a <- class.project(dfs, "rails")
b <- class.project(dfs, "")

a <- prepare.project.df(merge.dataframes(dfs))
testidx <- which(1:nrow(a)%%4 == 0)
train <- a[-testidx,]
test <- a[testidx,]

# Trees
library(rpart)
a <- a[, -c(11)]
testidx <- which(1:nrow(a)%%4 == 0)
train <- a[-testidx,]
test <- a[testidx,]

treemodel <- rpart(merged~. - requester - num_comments - watchers - followers - sloc, data=a, method="class")
pred <- predict(treemodel, test)
rfcv(pred, test$merged)
pr <- prediction(pred, test$merged)
perf <- performance(pr, "prec", "rec")
plot(perf, col = "red") 

table(pred, test$merged)

printcp(treemodel)
plot(treemodel)
text(treemodel, use.n=T)
plotcp(treemodel)
post(treemodel, file="~/tree.ps")

# Random forests
library(randomForest)
a <- prepare.project.df(merge.dataframes(dfs))

model <- randomForest(merged~. - requester - num_comments - watchers - followers - sloc, data=a, importance = T)
print(model)
varImpPlot(model, type=1)
varImpPlot(model, type=2)

plot(model)

# Use it to predict values in the training set
# Plot ROC, recall-precision, calibration curves
OOB.votes <- predict (model, b, type="prob")
OOB.pred <- OOB.votes[,2]
pred.obj <- prediction (OOB.pred, b$merged)

OOB.pred <- predict (model, b$merged)
pred.obj <- prediction (OOB.pred, b$merged)

ROC.perf <- performance(pred.obj, "tpr","fpr")
plot (ROC.perf, colorize = T)

RP.perf <- performance(pred.obj, "rec","prec")
plot (RP.perf, colorize = T)

ROC.acc <- performance(pred.obj, "acc")
plot (ROC.acc, colorize = T)

# AUC, precision, recall
as.numeric(performance(pred.obj,"auc")@y.values)
as.numeric(performance(pred.obj,"acc")@y.values)
as.numeric(performance(pred.obj,"rec")@y.values)

plot  (RP.perf@alpha.values[[1]],RP.perf@x.values[[1]]);
lines (RP.perf@alpha.values[[1]],RP.perf@y.values[[1]]);
lines (ROC.perf@alpha.values[[1]],ROC.perf@x.values[[1]]);