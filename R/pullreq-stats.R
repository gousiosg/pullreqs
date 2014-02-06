#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/multiplots.R")
source(file = "R/utils.R")
source(file = "R/plots.R")

library(ggplot2)
library(xtable)
library(ellipse)
library(reshape)
library(digest)
library(scales)
library(cliffsd)
library(sqldf)

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
#system("cat random-projects.txt|tr '/' ' '|tr -d '\"' > foo; mv foo random-projects.txt")
#set.seed(11)
#smpl <- projectstats[sample(which(
#   (projectstats$language=="Ruby" | projectstats$language=="Java" | projectstats$language=="Scala"| projectstats$language=="Python") &
    #projectstats$contributors > projectstats$project_members &
#    projectstats$project_members > 0 &
#    projectstats$pull_requests >= 200), 1000, replace = FALSE), ]
#write.table(smpl[,c(1,11)], file = "random-projects.txt", sep = " ", row.names=FALSE, col.names=FALSE)

#print("Producing the data files...")
# Produce the datafiles
# Those can be run in parallel like so:
# system("bin/all_projects.sh -p 4 -d data projects.txt")

print("Loading data files..")
all <- load.data(project.list)


#  Number of projects per language
for(language in c("ruby", "java", "python", "scala")) {
  printf("%d projects in %s", length(unique(subset(all, lang == language)$project_name)), language)
}

# Number of pullrequests per language
for(language in c("ruby", "java", "python", "scala")) {
  printf("%d pullreqs %s", nrow(subset(all, lang == language)), language)
}

# Percentage of merged pull reqs per identified cretirion
for(cretirion in unique(all$merged_using)) {
  printf("%f pullreqs merged with %s", (nrow(subset(all, merged_using==cretirion))/nrow(all)), cretirion)
}

# Columns used in building models
columns = c("team_size", "num_commits", "files_changed",
            "perc_external_contribs", "sloc", "src_churn", "test_churn",
            "commits_on_files_touched", "test_lines_per_kloc",
            "prev_pullreqs", "requester_succ_rate", "num_comments")

merged <- subset(all, merged == TRUE)
non_merged <- subset(all, merged == FALSE)

# Descriptive statistics accross all projects
used <- subset(all, select=columns)

# Why test_cases_per_kloc and asserts_per_kloc are excluded from further analysis
cor.test(all$test_lines_per_kloc, all$test_cases_per_kloc, method="spearman")
cor.test(all$test_lines_per_kloc, all$asserts_per_kloc, method="spearman")

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
printf("Avg pullreq merged: %f", (nrow(merged)/nrow(all))*100)

# Merge % mean
a <- do.call(rbind, Map(function(x) {
  total = nrow(x)
  merged = nrow(subset(x, merged_at > 0))
  unmerged_perc = (100 * (total - merged))/total
  merged_perc = 100 - unmerged_perc
  rbind(data.frame(project=project.name(x), status="merged", value=merged_perc),
        data.frame(project=project.name(x), status="unmerged", value=unmerged_perc))
}, dfs))

printf("Mean of pullreq merged: %f", mean(subset(a, status == "merged")$value))
printf("Shapiro-Wilkes pullreq merged perc pvalue: %f", shapiro.test(subset(a, status == "merged")$value)$p.value)

# Merged pull reqs quantiles
to.days <- function(x) {
  x / 60 / 24
}
printf("Merge time in days quantiles: 95: %f, 90: %f, 80: %f",
        to.days(quantile(merged$mergetime_minutes, 0.95)),
        to.days(quantile(merged$mergetime_minutes, 0.90)),
        to.days(quantile(merged$mergetime_minutes, 0.80)))

merged.fast <- subset(merged, mergetime_minutes < 61)
printf("Num pull reqs merged in an hour: %f", nrow(merged.fast))
printf("Perc pull reqs merged in an hour: %f", nrow(merged.fast)/nrow(merged))

printf("Perc fast pull reqs merged from main team members: %f",
       nrow(subset(merged.fast,main_team_member == TRUE))/nrow(merged.fast))

ranksum(subset(merged, mergetime_minutes < 61)$src_churn,
        subset(merged, mergetime_minutes >= 61)$src_churn,
        "pull request churn and merge time -")

# Unmerged pull request lifetime vs merged
non_merged$type <- "unmerged"
merged$type <- "merged"
lifetimes <- rbind(non_merged, merged)

p <-  ggplot(lifetimes, aes(x = type, y = lifetime_minutes)) +
  geom_boxplot()  + scale_y_log10() + xlab("Pull request") +
  ylab("Time to close in minutes (log))")
store.pdf(p, plot.location, "close-merged-unmerged.pdf")

ranksum(merged$lifetime_minutes, non_merged$lifetime_minutes,
        "Lifetime of merged and unmerged pull requests")

# Origin of pull request (main team or external) and mergetime
# Box plot of merge time between main and external team members
teams <- merged
teams$team <- lapply(teams$main_team_member, function(x){if(x){"main"}else{"external"}})
teams$team <- as.factor(teams$team)

p <- ggplot(teams, aes(x = team, y = mergetime_minutes)) +
  geom_boxplot()  + scale_y_log10() + xlab("Team") +
  ylab("Time to merge in minutes (log))")
store.pdf(p, plot.location, "merge-internal-external.pdf")

# Rank correlation to see whether the populations differ significantly
ranksum(subset(merged, main_team_member == T)$mergetime_minutes, 
        subset(merged, main_team_member == F)$mergetime_minutes, 
        "pull request origin and merge time")

# Pull requests merge time at the proejct level
print("Cross correlation table for median time to merge vs other variables")
col1 <- c(columns, 'mergetime_minutes')
selected <- subset(merged, TRUE, select = col1)
cot.tab <- cor(aggregate(selected, list(selected$project_name), length),
    method = "spearman")

mean.mergetime.per.project <- aggregate(mergetime_minutes ~ project_name, data = merged, median)

printf("Perc projects with mean mergetime < 1 week: %f",
              nrow(subset(mean.mergetime.per.project, mergetime_minutes < 10080))/
                nrow(mean.mergetime.per.project))

pullreqs.per.project <- aggregate(merged, list(merged$project_name), length)[c('Group.1','mergetime_minutes')]
a <- merge(x = mean.mergetime.per.project, y = pullreqs.per.project, by = 'Group.1')

printf("Cor between num(pull_reqs), mean(time_to_merge) %f",
              cor.test(a$mergetime_minutes.x, a$mergetime_minutes.y,
              method = "spearman")$estimate)

mean.size.pp <- subset(aggregate(merged, list(merged$project_name), mean),
                       select=c(Group.1, sloc))
a <- merge(mean.mergetime.per.project, mean.size.pp, by = 'Group.1')

printf("Cor between mean(sloc), mean(time_to_merge) %f",
              cor.test(a$mergetime_minutes, a$sloc,
                       method = "spearman")$estimate)

# Pull request sizes
printf("Pullreqs commits quantiles: 95: %f, 90: %f, 80: %f",
       quantile(all$num_commits, 0.95),
       quantile(all$num_commits, 0.90),
       quantile(all$num_commits, 0.80))

printf("Median commits %f", median(all$num_commits))

printf("Pullreqs num_files quantiles: 95: %f, 90: %f, 80: %f",
       quantile(all$files_changed, 0.95),
       quantile(all$files_changed, 0.90),
       quantile(all$files_changed, 0.80))

printf("Median commits %f", median(all$files_changed))

printf("Merged pull reqs lines quantiles: 95: %f, 90: %f, 80: %f",
       quantile(all$src_churn + all$test_churn, 0.95),
       quantile(all$src_churn + all$test_churn, 0.90),
       quantile(all$src_churn + all$test_churn, 0.80))

printf("Median commits %f", median(all$src_churn + all$test_churn))

# Pull requests and tests
printf("Perc pull reqs modifying non-code: %f", 1 - nrow(subset(all, src_churn > 0 | test_churn >0))/nrow(all))
printf("Perc Pull reqs modifying test code: %f", nrow(subset(all, test_churn > 0))/nrow(all))
printf("Perc Pull reqs modifying test code exclusively: %f", nrow(subset(all, test_churn > 0 & src_churn == 0))/nrow(all))
printf("Perc test pull reqs merged: %f", nrow(subset(all, test_churn > 0 & merged == T))/nrow(subset(all, test_churn > 0)))

ranksum(subset(merged, test_churn > 0, c(mergetime_minutes))$mergetime_minutes,
        subset(merged, test_churn == 0, c(mergetime_minutes))$mergetime_minutes,
        "existence of tests and mergetime")

p <- ggplot(subset(merged, TRUE, c(mergetime_minutes, has_tests))) + 
  aes( x=has_tests, y = mergetime_minutes) + geom_boxplot() + scale_y_log10()

store.pdf(p, plot.location, "tests-merge-time.pdf")

ranksum(subset(aggregate(cbind(test_lines_per_kloc, mergetime_minutes) ~ project_name, merged, mean), test_lines_per_kloc < 1000)$mergetime_minutes,
        subset(aggregate(cbind(test_lines_per_kloc, mergetime_minutes) ~ project_name, merged, mean), test_lines_per_kloc > 1000)$mergetime_minutes,
        "good testing vs mergetime")

mean.testing.per.project <- aggregate(cbind(test_lines_per_kloc, mergetime_minutes) ~ project_name, merged, mean)
ranksum(head(mean.testing.per.project[order(mean.testing.per.project$test_lines_per_kloc),], 20)$mergetime_minutes, 
        tail(mean.testing.per.project[order(mean.testing.per.project$test_lines_per_kloc),], 20)$mergetime_minutes)

# Pull request discusion
printf("Merged pull reqs comments quantiles: 95: %f, 90: %f, 80: %f",
       quantile(all$num_comments, 0.95),
       quantile(all$num_comments, 0.90),
       quantile(all$num_comments, 0.80))

cor.test(all$lifetime_minutes, all$num_comments, method = "spearman")
cor.test(merged$lifetime_minutes, merged$num_comments, method = "spearman")
cor.test(non_merged$lifetime_minutes, non_merged$num_comments, method = "spearman")

# Code review, pimp the data frame with info about code review
has.code.review <- function(row) {
  q = sprintf("select count(*) as cnt from pull_request_comments prc where prc.pull_request_id = %d", row$pull_req_id)
  printf("%s/%s",row$project_name,row$github_id)
  res <- dbSendQuery(con,q) 
  num_code_review <- fetch(res, n = -1)
  num_code_review > 0
}

all$code_review <- apply(all, 1, has.code.review)
reviewed <- subset(all, code_review == T)
non.reviewed <- subset(all, code_review == F)
printf("Pull reqs with code review: %d, %f%%", nrow(reviewed), nrow(reviewed)/nrow(all))
printf("Reviewed and merged %%: %f", nrow(subset(reviewed, merged == T))/nrow(reviewed))
ranksum(subset(reviewed, merged == T)$lifetime_minutes,
        subset(non.reviewed, merged == T)$lifetime_minutes,
        "code review and mergetime")

# Number of participants in pull request discussion
num.participants <- function(row) {
  q = sprintf("select count(distinct(user_id)) as participants from (select user_id from pull_request_comments where pull_request_id = %s union select user_id from issue_comments ic, issues i where i.id = ic.issue_id and i.pull_request_id = %s) as users", row[1], row[1])
  printf("%s/%s",row[2],row[4])
  res <- dbSendQuery(con,q) 
  participants <- fetch(res, n = -1)$participants
  print(participants)
  participants
}

all$num_participants <- apply(all, 1, num.participants)


# Pull request conflicts, do they affect merge time?
ranksum(subset(merged, conflict == T)$mergetime_minutes,
        subset(merged, conflict == F)$mergetime_minutes,
        "conflicts and merge time -")
