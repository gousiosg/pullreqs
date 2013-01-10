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
a$merged <- apply(a, 1, function(r){if(is.na(r[4])){0} else {1}})