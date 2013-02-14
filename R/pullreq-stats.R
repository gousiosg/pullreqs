source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/multiplots.R")
source(file = "R/plots.R")

library(ggplot2)
library(stargazer)

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
#set.seed(11)
#smpl <- projectstats[sample(which(
#   (projectstats$language=="Ruby" | projectstats$language=="Java" | projectstats$language=="Scala") & 
    #projectstats$contributors > projectstats$project_members & 
#    projectstats$project_members > 0 & 
#    projectstats$pull_requests > 10), 100, replace = FALSE), ]
#write.table(smpl[,c(1,11)], file = "random-projects.txt", sep = " ", row.names=FALSE, col.names=FALSE)
#system("cat random-projects.txt|tr '/' ' '|tr -d '\"' > foo; mv foo rnd-projects.txt")

#print("Producing the data files...")
# Produce the datafiles
# Those can be run in parallel like so:
# system("bin/all_projects.sh -p 4 -d data projects.txt")
# system("bin/all_projects.sh -p 4 -d data random-projects.txt")

print("Loading data files..")
dfs <- load.all(dir=data.file.location, pattern="*.csv$")

# Add derived columns
dfs <- addcol.merged(dfs)

# Merge all dataframes in a single dataframe
all <- merge.dataframes(dfs)

# Descriptive statistics accross all projects
stargazer(all, median = TRUE, caption = "Descriptive statistics of the examined dataset")


# Box plot of merge time between main and external team members
main.team.mergetimes <- subset(all, !is.na(merged_at) & main_team_member == "true", c(mergetime_minutes))
ext.team.mergetimes <- subset(all, !is.na(merged_at) & main_team_member == "false", c(mergetime_minutes))

main.team.mergetimes$team <- "main"
ext.team.mergetimes$team <- "external"
teams <- rbind(main.team.mergetimes, ext.team.mergetimes)
teams$team <- as.factor(teams$team)
ggplot(teams, aes(x = team, y = mergetime_minutes)) + 
  geom_boxplot()  + scale_y_log10() + 

# Rank correlation to see whether the populations differ significantly
mergetimes <- list(main = main.team.mergetimes$mergetime_minutes, ext = ext.team.mergetimes$mergetime_minutes)
test <- wilcox.test(x = mergetimes$main, y = mergetimes$ext, paired = FALSE)
printf("Merges by ")



store.pdf(plot.percentage.merged(dfs), plot.location, "perc-merged.pdf")

projects = c("junit", "puppet", "netty", 
             "akka", "chef", "jekyll", "jenkins", "libgit")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-freq.pdf")
store.pdf(plot.accept.lifetime.boxplot(dfs, projects), plot.location, "lifetime-boxplot.pdf")

projects = c("akka", "scala", "junit", "scala-ide", "scalaz")
store.pdf(plot.accept.lifetime.freq(dfs, projects), plot.location, "lifetime-scala-freq.pdf")

# Plot cross-correlation plots for variables in datafiles
columns = c("team_size", "num_commits", "num_comments", "files_changed", "perc_external_contribs", "sloc", "src_churn",
            "test_churn", "commits_on_files_touched", "test_lines_per_1000_lines", "prev_pullreqs", "requester_succ_rate",
            "watchers", "followers")
plot.crosscor(subset(all, select=columns), "Cross correlation among measured variables")

store.multi(plot.multicor.all_dataframes, dfs, colnames(dfs[[1]]), "multicorrelations")