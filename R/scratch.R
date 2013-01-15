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
dfs <- load.all(dir=data.file.location)
a = dfs[[39]]
a$merged <- apply(a, 1, function(r){if(is.na(r[4])){0} else {1}})
a <- a[,c(8:22)]
a <- a[,-c(3,4)]
testidx <- which(1:nrow(a)%%4 == 0)
train <- a[-testidx,]
test <- a[testidx,]

library(rpart)
treemodel <- rpart(merged~churn+files_changed, data=a, method="anova")
printcp(treemodel)
text(treemodel, use.n=T)
plot(treemodel)
plotcp(treemodel)
post(treemodel, file="~/tree.ps")

library(randomForest)
library(ROCR) 
# Train the classifier
model <- randomForest(merged~. - num_commit_comments - num_issue_comments, data=train, importance = T, do.Trace = 100)

# Use it to predict values in the training set
predict <- predict(model, test)
t <- table(observed = test$merged, predicted = predict)
importance(model)
perf <- performance(predict(predict,test$merged),"tpr","fpr")
plot(perf, col = "red") 
