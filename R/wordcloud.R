if (!"wordcloud" %in% installed.packages()) install.packages("wordcloud")
library(wordcloud)

rm(list = ls(all = TRUE))

source(file = "R/variables.R")
source(file = "R/utils.R")

all <- load.data()

all$name <- apply(all, 1, function(x){strsplit(x[['project_name']], "/")[[1]][2]})

words <- aggregate(github_id ~ name, all, length)

store.pdf(wordcloud(words$name, words$github_id), plot.location, "wordcloud.pdf")