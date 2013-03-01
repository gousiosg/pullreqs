rm(list = ls(all = TRUE))

source(file = "R/multiplots.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/plots.R")

library(ggplot2)
library(stargazer)
library(ellipse)
library(scales)
library(orddom)

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
            "prev_pullreqs", "requester_succ_rate", "num_comments")

merged <- subset(all, merged == TRUE)
non_merged <- subset(all, merged == FALSE)
used <- subset(all, select=columns)

# Descriptive statistics accross all projects
#stargazer(used, median = TRUE, caption = "Descriptive statistics of the examined dataset")

# Cross correlation matrix accross all model variables
ctab <- cor(used, method = "spearman")
colorfun <- colorRamp(c("#ff0000","white","#3366CC"), space="Lab")
store.pdf(plotcorr(ctab, 
                   col=rgb(colorfun((ctab+1)/2), maxColorValue=255), 
                   outline = FALSE), plot.location, 
          "cross-cor.pdf")

# Percentage of merged vs unmerged pull requests accross projects
store.pdf(plot.percentage.merged(dfs), plot.location, "perc-merged.pdf")

# Time to merge pull request box plots histogram
p <- ggplot(merged, aes(x = mergetime_minutes)) +  
  geom_histogram() + scale_x_log10(labels=comma) +
  xlab("Merge time in minutes (log)") +
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
store.pdf(p, plot.location, "pr-num-comments-hist.pdf")

# Merge % overall
print(sprintf("Avg pullreq merged: %f", (nrow(merged)/nrow(all))*100))

# Merge % mean
a <- do.call(rbind, Map(function(x) {
  total = nrow(x)
  merged = nrow(subset(x, merged_at > 0))
  unmerged_perc = (100 * (total - merged))/total
  merged_perc = 100 - unmerged_perc
  rbind(data.frame(project=project.name(x), status="merged", value=merged_perc),
        data.frame(project=unique(x[[1]][1]), status="unmerged", value=unmerged_perc))
}, dfs))

print(sprintf("Mean of pullreq merged: %f", mean(subset(a, status == "merged")$value)))
print(sprintf("Shapiro-Wilkes pullreq merged perc pvalue: %f", shapiro.test(subset(a, status == "merged")$value)$p.value))

# Merged pull reqs quantiles
to.days <- function(x) {
  x / 60 / 24
}
print(sprintf("Merged pull reqs quantiles: 95: %f, 90: %f, 80: %f", 
              to.days(quantile(merged$mergetime_minutes, 0.95)), 
              to.days(quantile(merged$mergetime_minutes, 0.90)), 
              to.days(quantile(merged$mergetime_minutes, 0.80))))

merged.fast <- subset(merged, mergetime_minutes < 61)
print(sprintf("Perc pull reqs merged in an hour: %f", 
              nrow(merged.fast)/nrow(merged)))

print(sprintf("Perc fast pull reqs merged from main team members: %f", 
              nrow(subset(merged.fast,main_team_member == "true"))/nrow(merged.fast)))

fast.pr.vs.slow <- wilcox.test(x = subset(merged, mergetime_minutes < 61, c('src_churn'))$src_churn, 
                               y = subset(merged, mergetime_minutes >= 61, c('src_churn'))$src_churn)
orddom <- orddom(subset(merged, mergetime_minutes < 61, c('src_churn'))$src_churn, 
                 subset(merged, mergetime_minutes > 61, c('src_churn'))$src_churn) 

printf(sprintf("Src churn in fast vs slow pull reqs: wilcox: %f, p %f, effect: %f"))

# Unmerged pull request lifetime vs merged
non_merged$type <- "unmerged"
merged$type <- "merged"
lifetimes <- rbind(non_merged, merged)

p <-  ggplot(lifetimes, aes(x = type, y = lifetime_minutes)) + 
  geom_boxplot()  + scale_y_log10() + xlab("Pull request") + 
  ylab("Time to close in minutes (log))")
store.pdf(p, plot.location, "close-merged-unmerged.pdf")

closetimes <- list(closed = non_merged$lifetime_minutes, 
                   merged = merged$lifetime_minutes)
w <- wilcox.test(x = closetimes$closed, y = closetimes$merged, paired = FALSE)
print(sprintf("Wilcox: pullreq merge main/external team: n_1 = %d, n_2 = %d V = %f, p < %f", length(closetimes$closed), length(closetimes$merged), w$statistic, w$p.value))
print(sprintf("Cliff's delta pullreq merge main/external team :%f", cliffs.d(closetimes$closed, closetimes$merged)))

# Team size
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


# Pull requests merge time at the proejct level
print("Cross correlation table for mean time to merge vs other variables")
col1 <- c(columns, 'mergetime_minutes')
cor(subset(aggregate(merged, list(merged$project_name), mean), select = col1), 
    method = "spearman")

mean.mergetime.per.project <- aggregate(merged, list(merged$project_name), mean)[c('Group.1','mergetime_minutes')]

print(sprintf("Perc projects with mean mergetime < 1 week: %f", 
              nrow(subset(mean.mergetime.per.project, mergetime_minutes < 10080))/
                nrow(mean.mergetime.per.project)))

pullreqs.per.project <- aggregate(merged, list(merged$project_name), length)[c('Group.1','mergetime_minutes')]
a <- merge(x = mean.mergetime.per.project, y = pullreqs.per.project, by = 'Group.1')

print(sprintf("Cor between num(pull_reqs), mean(time_to_merge) %f", 
              cor.test(a$mergetime_minutes.x, a$mergetime_minutes.y, 
              method = "spearman")$estimate))

# Rank correlation to see whether the populations differ significantly
mergetimes <- list(main = main.team.mergetimes$mergetime_minutes, ext = ext.team.mergetimes$mergetime_minutes)
w <- wilcox.test(x = mergetimes$main, y = mergetimes$ext, paired = FALSE)
print(sprintf("Wilcox: pullreq merge main/external team: n1 = %d, n2 = %d V = %f, p < %f", length(mergetimes$main), length(mergetimes$ext), w$statistic, w$p.value))
print(sprintf("Cliff's delta pullreq merge main/external team :%f", cliffs.d(mergetimes$main, mergetimes$ext)))

# Pull request sizes

print(sprintf("Pullreqs commits quantiles: 95: %f, 90: %f, 80: %f", 
              quantile(all$num_commits, 0.95), 
              quantile(all$num_commits, 0.90), 
              quantile(all$num_commits, 0.80)))

print(sprintf("Median commits %f", median(all$num_commits)))

print(sprintf("Pullreqs num_files quantiles: 95: %f, 90: %f, 80: %f", 
              quantile(all$files_changed, 0.95), 
              quantile(all$files_changed, 0.90), 
              quantile(all$files_changed, 0.80)))

print(sprintf("Median commits %f", median(all$files_changed)))

print(sprintf("Merged pull reqs lines quantiles: 95: %f, 90: %f, 80: %f", 
              quantile(all$src_churn + all$test_churn, 0.95), 
              quantile(all$src_churn + all$test_churn, 0.90), 
              quantile(all$src_churn + all$test_churn, 0.80)))

print(sprintf("Median commits %f", median(all$src_churn + all$test_churn)))

print(sprintf("Perc pull reqs modifying non-code: %f", 1 - nrow(subset(all, src_churn > 0 | test_churn >0))/nrow(all)))
print(sprintf("Perc Pull reqs modifying test code: %f", nrow(subset(all, test_churn > 0))/nrow(all)))
print(sprintf("Perc Pull reqs modifying test code: %f", nrow(subset(all, test_churn > 0 & src_churn == 0))/nrow(all)))
print(sprintf("Perc test pull reqs merged: %f", nrow(subset(all, test_churn > 0 & merged == TRUE))/subset(all, merged == TRUE))))

time_tests <- subset(merged, test_churn > 0, c(mergetime_minutes))$mergetime_minutes
time_no_tests <- subset(merged, test_churn == 0, c(mergetime_minutes))$mergetime_minutes
w <- wilcox.test(time_tests, time_no_tests)

print(sprintf("Wilcox: pullreq merge time : tests = %d, no_tests = %d V = %f, p < %f", length(time_tests), length(time_no_tests), w$statistic, w$p.value))
print(sprintf("Cliff's delta pullreq merge test/no test :%f", cliffs.d(time_tests, time_no_tests)))

# Pull request discusion

print(sprintf("Merged pull reqs comments quantiles: 95: %f, 90: %f, 80: %f", 
              quantile(all$num_comments, 0.95), 
              quantile(all$num_comments, 0.90), 
              quantile(all$num_comments, 0.80)))

cor.test(all$lifetime_minutes, all$num_comments, method = "spearman")
cor.test(merged$lifetime_minutes, merged$num_comments, method = "spearman")
cor.test(non_merged$lifetime_minutes, non_merged$num_comments, method = "spearman")
fast <- subset(merged, mergetime_minutes < 6600)
