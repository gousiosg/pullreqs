library(ggplot2)
library(igraph)
source(file = "R/variables.R")
source(file = "R/utils.R")

plot.hist.all_files(dir = "~/Developer/pullreqs/data/")
plot.mutlicor(dfs[[12]][5:15])
plot.mutlicor(dfs[[1]][5:18], as.character(dfs[[1]]$project_name[1]))
                    
store.multi(plot.multicor.all_dataframes, dfs, colnames(dfs[[1]]), "multicorrelations")
store.multi(plot.hist.all_dataframes, dfs, c(5:6,8), name="foo")

dfs <- load.all(dir=data.file.location)

store.pdf(plot.percentage.merged(dfs), plot.location, "perc-merged.pdf")

projects = c("junit", "puppet", "netty", 
             "akka", "chef", "jekyll", "jenkins", "libgit")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-freq.pdf")
store.pdf(plot.accept.lifetime.boxplot(dfs, projects), plot.location, "lifetime-boxplot.pdf")

projects = c("akka", "scala", "junit", "scala-ide", "scalaz")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-scala-freq.pdf")