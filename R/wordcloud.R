#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source(file = "R/cmdline.R")
source(file = "R/utils.R")

if (!"wordcloud" %in% installed.packages()) install.packages("wordcloud")
library(wordcloud)

all <- load.data(project.list)

all$name <- apply(all, 1, function(x){strsplit(x[['project_name']], "/")[[1]][2]})

words <- aggregate(github_id ~ name, all, length)

words <- subset(words, github_id > 200)

store.pdf(wordcloud(words$name, words$github_id), plot.location, "wordcloud.pdf")
dev.off()
