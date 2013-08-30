rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/multiplots.R")
source(file = "R/variables.R")
source(file = "R/utils.R")
source(file = "R/plots.R")

library(ggplot2)
library(xtable)
library(ellipse)
library(reshape)
library(scales)
library(cliffsd)

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
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs, 200)

# Why test_cases_per_kloc and asserts_per_kloc are excluded from further analysis
cor.test(all$test_lines_per_kloc, all$test_cases_per_kloc, method="spearman")
cor.test(all$test_lines_per_kloc, all$asserts_per_kloc, method="spearman")

# Columns used in building models
columns = c("team_size", "num_commits", "files_changed",
            "perc_external_contribs", "sloc", "src_churn", "test_churn",
            "commits_on_files_touched", "test_lines_per_kloc",
            "prev_pullreqs", "requester_succ_rate", "num_comments")

merged <- subset(all, merged == TRUE)
non_merged <- subset(all, merged == FALSE)

# Descriptive statistics accross all projects
used <- subset(all, select=columns)

## Cross correlation matrix accross all model variables
ctab <- cor(used, method = "spearman", use='complete.obs')
colorfun <- colorRamp(c("#ff0000","white","#3366CC"), space="Lab")
store.pdf(plotcorr(ctab,
                   #col = 'grey',
                   col=rgb(colorfun((ctab+1)/2), maxColorValue=255),
                   outline = FALSE),
          plot.location,
          "cross-cor.pdf")
print(xtable(ctab,
             caption="Cross correlation matrix (Spearman) between examined factors",
             label="tab:crosscor"),
         type = "latex",
         size = "small",
         file = paste(latex.location, "cross-cor.tex", "/"))

ctab.m <- melt(ctab)
p <- ggplot(ctab.m, aes(X1, X2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(space = "Lab") +
  labs(x = '', y = '') +
  theme(axis.text = element_text(size = 11),
        axis.text.x = element_text(angle = -90, hjust = 0, vjust = 0.5))
store.pdf(p, plot.location, "cross-cor-heat.pdf")

# Percentage of merged vs unmerged pull requests accross projects
a <- all
merged.perc <- sqldf("select project_name, (select count(*) from a a1 where a1.project_name = a.project_name and merged = 'TRUE') *1.0/ (select count(*) from a a1 where a1.project_name = a.project_name) as ratio_merged from a group by project_name order by ratio_merged")
merged.perc$order = as.numeric(rownames(merged.perc))
p <- ggplot(merged.perc, aes(x = order, y = ratio_merged)) +
  geom_bar(stat="identity", color = "#ff3333") +
  theme(axis.text.x=element_blank()) +
  ylab("Percentage") +
  xlab("Project")
store.pdf(p, plot.location, 'perc-merged.pdf')

# This is to check very low scores in merge % is due to the lack 
# of data as a result of the project not having an activated issue tracker
# check.has.bugs(df, credentials = "username:password") {
#   has.bugs <- function(x) {
#     library(RCurl)
#     printf("Checking %s", x)
#     h = basicHeaderGatherer()
#     getURI(sprintf("https://api.github.com/repos/%s/issues", x),
#            userpwd=credentials,  httpauth = 1L, headerfunction = h$update)
#     h$value()['status'] == 200
#   }
#   df$has_bugs <- lapply(df$project_name, has_bugs)
# }
#
# check.has.bugs(merged.perc)
rm(a)

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
main.team.mergetimes <- subset(merged, main_team_member == T)$mergetime_minutes
ext.team.mergetimes <- subset(merged, main_team_member == F)$mergetime_minutes

main.team.mergetimes$team <- "main"
ext.team.mergetimes$team <- "external"
teams <- rbind(main.team.mergetimes, ext.team.mergetimes)
teams$team <- as.factor(teams$team)
p <- ggplot(teams, aes(x = team, y = mergetime_minutes)) +
  geom_boxplot()  + scale_y_log10() + xlab("Team") +
  ylab("Time to merge in minutes (log))")
store.pdf(p, plot.location, "merge-internal-external.pdf")

# Rank correlation to see whether the populations differ significantly
ranksum(main.team.mergetimes, ext.team.mergetimes, "pull request origin and merge time")

# Pull requests merge time at the proejct level
print("Cross correlation table for mean time to merge vs other variables")
col1 <- c(columns, 'mergetime_minutes')
cor(subset(aggregate(merged, list(merged$project_name), mean), select = col1),
    method = "spearman")

mean.mergetime.per.project <- aggregate(merged, list(merged$project_name), mean)[c('Group.1','mergetime_minutes')]

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
printf("Perc test pull reqs merged: %f", nrow(subset(all, test_churn > 0 & merged == TRUE))/nrow(subset(all, merged == TRUE)))

ranksum(subset(merged, test_churn > 0, c(mergetime_minutes))$mergetime_minutes,
        subset(merged, test_churn == 0, c(mergetime_minutes))$mergetime_minutes,
        "existence of tests and mergetime")

# Pull request discusion
printf("Merged pull reqs comments quantiles: 95: %f, 90: %f, 80: %f",
       quantile(all$num_comments, 0.95),
       quantile(all$num_comments, 0.90),
       quantile(all$num_comments, 0.80))

cor.test(all$lifetime_minutes, all$num_comments, method = "spearman")
cor.test(merged$lifetime_minutes, merged$num_comments, method = "spearman")
cor.test(non_merged$lifetime_minutes, non_merged$num_comments, method = "spearman")

# Pull request conflicts, do they affect merge time?
ranksum(subset(merged, conflict == T)$mergetime_minutes,
        subset(merged, conflict == F)$mergetime_minutes,
        "conflicts and merge time -")
