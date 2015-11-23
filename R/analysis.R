rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(plyr)
library(reshape)

source(file = "R/data-preparation.R")

# CI use -- Does it improve merge time?
distinct.ci <- all[, .(ci = unique(ci)), by = project_name]
projects.many.cis <- subset(aggregate(ci ~ project_name, distinct.ci, length), ci >1 )
projects.many.cis <- rename(projects.many.cis, c('ci'='num_cis'))

# PRs for projects that have more than 1 CI in their time frame
prs.projects.many.cis <- data.table(merge(projects.many.cis, all, by.x='project_name', by.y = 'project_name'))

# Projects that have pull requests with unknown CI
projects.unknown.ci <- as.character(unique(subset(prs.projects.many.cis, as.character(ci) == 'unknown')$project_name))

# PRs of projects with unknown CI
prs.projects.with.unknown.ci <- prs.projects.many.cis[project_name %in% projects.unknown.ci]

# Does CI improve merge time accross pull requests? Yes!
ranksum(remove.outliers(subset(prs.projects.with.unknown.ci,as.character(ci) == 'unknown' & merged == "FALSE")$lifetime_minutes),
        remove.outliers(subset(prs.projects.with.unknown.ci,as.character(ci) != 'unknown' & merged == "FALSE")$lifetime_minutes))

ggplot(med.merge.per.project) + 
  aes(x = variable, y = value) + 
  geom_boxplot() + 
  scale_y_log10()


med.merge.time.no.ci <- 
  aggregate(lifetime_minutes~project_name, 
            subset(prs.projects.with.unknown.ci, as.character(ci) == 'unknown'), 
            median)

med.merge.time.with.ci <- 
  aggregate(lifetime_minutes~project_name, 
            subset(prs.projects.with.unknown.ci, as.character(ci) != 'unknown'), 
            median)

# Does it improve merge time accross projects? Nope!
med.merge.per.project <- merge(med.merge.time.no.ci, med.merge.time.with.ci, by = 'project_name')
med.merge.per.project <- rename(med.merge.per.project, c('lifetime_minutes.x'='no_ci', 
                                                     'lifetime_minutes.y' = 'with_ci'))
med.merge.per.project$num_prs_no_ci <- 
  apply(med.merge.per.project, 1, 
        function(x) {
          nrow(subset(prs.projects.with.unknown.ci, as.character(ci) == 'unknown' & project_name==x[1]))
          })

med.merge.per.project$num_prs_ci <- 
  apply(med.merge.per.project, 1, 
        function(x) {
          nrow(subset(prs.projects.with.unknown.ci, as.character(ci) != 'unknown' & project_name==x[1]))
        })

med.merge.per.project$no_ci_ratio <- med.merge.per.project$num_prs_no_ci/ (med.merge.per.project$num_prs_no_ci + med.merge.per.project$num_prs_ci)

ranksum(med.merge.per.project$no_ci, med.merge.per.project$with_ci)

to.plot <- melt(med.merge.per.project[,c('project_name', 'no_ci', 'with_ci')])
ggplot(to.plot) + 
  aes(x = variable, y = value) + 
  geom_boxplot() + 
  scale_y_log10()



