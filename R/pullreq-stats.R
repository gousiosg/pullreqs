rm(list = ls(all = TRUE))

source(file = "R/multiplots.R")
source(file = "R/variables.R")
source(file = "R/utils.R")

library(ggplot2)
library(stargazer)
library(ellipse)
library(scales)

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

# Columns used in building models
columns = c("team_size", "num_commits", "files_changed", 
            "perc_external_contribs", "sloc", "src_churn", "test_churn", 
            "commits_on_files_touched", "test_lines_per_1000_lines", 
            "prev_pullreqs", "requester_succ_rate")

merged <- subset(all, merged == TRUE)
used <- subset(all, select=columns)

# Descriptive statistics accross all projects
stargazer(used, median = TRUE, caption = "Descriptive statistics of the examined dataset")

# Cross correlation matrix accross all model variables
ctab <- cor(used, method = "spearman")
colorfun <- colorRamp(c("#ff0000","white","#3366CC"), space="Lab")
store.pdf(plotcorr(ctab, 
                   col=rgb(colorfun((ctab+1)/2), maxColorValue=255), 
                   outline = FALSE), plot.location, 
          "cross-cor.pdf")

# Box plot of merge time between main and external team members
main.team.mergetimes <- subset(all, !is.na(merged_at) & main_team_member == "true", c(mergetime_minutes))
ext.team.mergetimes <- subset(all, !is.na(merged_at) & main_team_member == "false", c(mergetime_minutes))

main.team.mergetimes$team <- "main"
ext.team.mergetimes$team <- "external"
teams <- rbind(main.team.mergetimes, ext.team.mergetimes)
teams$team <- as.factor(teams$team)
p <- ggplot(teams, aes(x = team, y = mergetime_minutes)) + 
  geom_boxplot()  + scale_y_log10() + xlab("Team") + 
  ylab("Time to merge in minutes (log))")
store.pdf(p, plot.location, "merge-internal-external.pdf")

# Rank correlation to see whether the populations differ significantly
mergetimes <- list(main = main.team.mergetimes$mergetime_minutes, ext = ext.team.mergetimes$mergetime_minutes)
w <- wilcox.test(x = mergetimes$main, y = mergetimes$ext, paired = FALSE)
print(sprintf("Wilcox: pullreq merge main/external team: n1 = %d, n2 = %d V = %f, p < %f", length(mergetimes$main), length(mergetimes$ext), w$statistic, w$p.value))
print(sprintf("Cliff's delta pullreq merge main/external team :%f", cliffs.d(mergetimes$main, mergetimes$ext)))

# Percentage of merged vs unmerged pull requests accross projects
store.pdf(plot.percentage.merged(dfs), plot.location, "perc-merged.pdf")

# Time to merge pull request box plots histogram
p <- ggplot(merged, aes(x = mergetime_minutes)) +  
  geom_histogram() + scale_x_log10(labels=comma) + xlab("Merge time in minutes (log)") +
  ylab("Number of pull requests")
store.pdf(p, plot.location, "pr-lifetime-hist.pdf")

# Size of pull request patch 
all$size <- all$src_churn + all$test_churn
p <- ggplot(all, aes(x = size)) +  
  geom_histogram() + scale_x_log10(labels=comma) + 
  xlab("Lines of code changed in pull request (log)") +
  ylab("Number of pull requests")
store.pdf(p, plot.location, "pr-size-hist.pdf")

# Size of pull request - files touched
p <- ggplot(all, aes(x = files_changed)) +  
  geom_histogram(binwidth = 0.2) + scale_x_log10(labels=comma) + 
  xlab("Number of files changed by the pull request (log)") +
  ylab("Number of pull requests")
store.pdf(p, plot.location, "pr-size-files-changed-hist.pdf")

# Size of pull request comments
p <- ggplot(all, aes(x = num_comments)) +  
  geom_histogram(binwidth = 0.2) + scale_x_log10(labels=comma) + 
  xlab("Number of code review and discussion comments (log)") +
  ylab("Number of pull requests")
store.pdf(p, plot.location, "pr-num-comments.pdf")
