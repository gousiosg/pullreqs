#install.packages("randomForest")
#install.packages("ggplot2")
#install.packages("ROCR")
#install.packages("stargazer")
#install.packages("ellipse")
#install.packages("cvTools")

# 1. first run this
library(ggplot2)
library(randomForest)
library(ROCR) 
library(stargazer)
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/multiplots.R")
source(file = "R/classification.R")
# end 1.

print(sprintf("Current directory is: %s", getwd()))

if(length(list.files(pattern="R")) == 0) {
  print("Cannot find the R directory")
  print("Change to the checkout directory before running this script")
  quit()
}

# The following will compute some basic project statistics
#source(file = "R/dataset-stats.R")

# Take a random sample of projects to analyze
#print("Sampling projects to analyze")
#set.seed(1)
#smpl <- projectstats[sample(which(
#  (projectstats$language=="Ruby" | projectstats$language=="Java" | projectstats$language=="Scala") & 
#    projectstats$contributors > projectstats$project_members & 
#    projectstats$project_members > 0 & 
#    projectstats$pull_requests > 50), 50, replace = FALSE), ]
#write.table(smpl[,c(1,8)], file = "random-projects.txt", sep = " ", row.names=FALSE, col.names=FALSE)
#system("cat random-projects.txt|tr '/' ' '|tr -d '\"' > foo; mv foo random-projects.txt")

print("Producing the data files...")
# Produce the datafiles
# Those can be run in parallel like so:
# system("bin/all_projects.sh -p 4 -d data projects.txt")
# system("bin/all_projects.sh -p 4 -d data random-projects.txt")

# 2. Load the data from the data files
print("Loading data files..")
dfs <- load.all(dir=data.file.location)

# Add derived columns
dfs <- addcol.merged(dfs)

# Merge all dataframes in a single dataframe
merged <- merge.dataframes(dfs)
# end 2.

# Plot cross-correlation plots for variables in datafiles
columns = c("team_size", "num_commits", "num_comments", "files_changed", "perc_external_contribs", "sloc", "src_churn",
            "test_churn", "commits_on_files_touched", "test_lines_per_1000_lines", "prev_pullreqs", "requester_succ_rate",
            "watchers", "followers")
project = "diaspora"
plot.crosscor(subset(get.project(dfs, project), select=columns), project)
plot.crosscor(subset(merged, select=columns), "Cross correlation among measured variables")

store.multi(plot.multicor.all_dataframes, dfs, colnames(dfs[[1]]), "multicorrelations")
store.multi(plot.hist.all_dataframes, dfs, c(5:6,8), name="foo")

store.pdf(plot.percentage.merged(dfs), plot.location, "perc-merged.pdf")

projects = c("junit", "puppet", "netty", 
             "akka", "chef", "jekyll", "jenkins", "libgit")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-freq.pdf")
store.pdf(plot.accept.lifetime.boxplot(dfs, projects), plot.location, "lifetime-boxplot.pdf")

projects = c("akka", "scala", "junit", "scala-ide", "scalaz")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-scala-freq.pdf")

# Train a model to predict whether a pull request will be merged or not
# a. Load the data

dfs <- load.all(dir=data.file.location)


