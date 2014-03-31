#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#


rm(list = ls(all = TRUE))

if (! "knitr" %in% installed.packages()) install.packages("knitr", src=TRUE)
if (! "RMySQL" %in% installed.packages()) install.packages("RMySQL")
if (! "ggplot2" %in% installed.packages()) install.packages("ggplot2")
if (! "reshape" %in% installed.packages()) install.packages("reshape")
if (! "sqldf" %in% installed.packages()) install.packages("sqldf")

library(RMySQL)
library(knitr)

# Genearte stats

stats <- function(owner, repo) {
  dirname = sprintf("%s-%s", owner,repo)
  print(sprintf("Running in %s", dirname))
  cwd <- getwd()
  dir.create(dirname)
  file.copy("report.Rmd", sprintf("%s/%s", dirname, "index.Rmd"))
  setwd(dirname)
  
  tryCatch({
    knit("index.Rmd")
    file.remove(sprintf("%s/%s", dirname, "index.Rmd"))
  }, error = function(e) {
    print(e)
    setwd(cwd)
    unlink(dirname, TRUE, TRUE)
  }, finally = {
    setwd(cwd)
  })
}

db <<- dbConnect(dbDriver("MySQL"), user = "ghtorrent", password = "ghtorrent", 
                 dbname = "ghtorrent", host = "dutiap")

projects <- read.csv('projects.txt', sep = ' ')
knit("index.Rmd")

projects$done <- apply(projects, 1, function(x){stats(x[1],x[2])})
