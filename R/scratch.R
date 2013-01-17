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
a = dfs[[37]]
a$merged <- apply(a, 1, function(r){if(is.na(r[4])){T} else {F}})
a <- a[,c(8:21)]
testidx <- which(1:nrow(a)%%4 == 0)
train <- a[-testidx,]
test <- a[testidx,]

# Trees
library(rpart)
a <- a[, -c(11)]
testidx <- which(1:nrow(a)%%4 == 0)
train <- a[testidx,]
test <- a[-testidx,]

treemodel <- rpart(merged ~., data=train, method="class")
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
# Train the classifier
model <- randomForest(merged~. - requester, data=a, importance = T, do.Trace = 10)
print(model)
varImpPlot(model, type=1)

plot(model)

# Use it to predict values in the training set
pred <- predict(model, test)
pr <- prediction(pred, test$merged)
perf <- performance(pr, "prec", "rec")
plot(perf, col = "red") 
importance(model)

# Carrot

