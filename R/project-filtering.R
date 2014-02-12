#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(RMySQL)
library(ggplot2)


####1. Determine which projects to generate datafiles for
con <- dbConnect(dbDriver("MySQL"), user = mysql.user, password = mysql.passwd,
                 dbname = mysql.db, host = mysql.host)

# All repos with pull requests
q <- "select u.login as owner, p.name as name, p.language as lang,
             pr.base_repo_id as repoid, count(*) as cnt
      from projects p, pull_requests pr, users u, pull_request_history prh
      where p.forked_from is null
        and p.name not regexp '^.*\\.github\\.com$'
        and p.name <> 'try_git'
        and p.name <> 'dotfiles'
        and p.name <> 'vimfiles'
        and u.id = p.owner_id
        and prh.action = 'opened'
        and prh.pull_request_id = pr.id
        and pr.base_repo_id = p.id
        and year(prh.created_at) < 2014
      group by pr.base_repo_id"

res <- dbSendQuery(con, unwrap(q))
pullreqs <- fetch(res, n = -1)

printf("Pullreqs per project (mean): %f", mean(pullreqs$cnt))
printf("Pullreqs per project (median): %f", median(pullreqs$cnt))
printf("Pullreqs per project (95 perc): %f", quantile(pullreqs$cnt, 0.95))
printf("Pullreqs per project (99 perc): %f", quantile(pullreqs$cnt, 0.99))
printf("Pullreqs per project (5 perc): %f", quantile(pullreqs$cnt, 0.05))

qplot(cnt, data = subset(pullreqs, cnt > 10),
      geom = "histogram", log = "x", ylab = "Number of projects",
      xlab = "Number of pull requests (log)")

# Filter top 1% of repos
repo.top.1perc <- subset(pullreqs, cnt > quantile(pullreqs$cnt, 0.99))

# Filter out repos not in Java, Scala, Ruby, Python
repos <- subset(repo.top.1perc, lang == "Java" | lang == "Scala" | lang == "Ruby" | lang == "Python")

write.csv(repos, "doc/dataset/dataset-repos.csv")

### At this point we need to run the detailed data extraction script with
### the generated dataset-repos.txt file as input 
### (bin/pull_req_data_extraction.rb)

####2. After datafiles have been created
library(sqldf)
require(plyr)

repos$project_name <- sprintf("%s/%s",repos$owner, repos$name)
# Load the top-level project list
all <- load.data("projects.txt")

# Apply exclusion criteria
#1. 70% of pull requests must have been extracted
q <- "select project_name, count(*) cnt from a group by project_name"
pullreq.counts <- sqldf(q, drv="SQLite", row.names=F)

repos$pr_extracted <- 
  apply(repos, 1, function(x){
    name = sprintf("%s/%s", x[1], x[2])
    num.pullreqs <- subset(pullreq.counts, project_name == name)
    num.pullreqs <- if (nrow(num.pullreqs) == 0){0}else{num.pullreqs$cnt}
    printf("name: %s pullreqs in database: %d, extracted: %s",name, num.pullreqs, x[5])
    num.pullreqs
  })

repos$completeness_criterion <- repos$pr_extracted > (repos$cnt * 0.7)

#2. Should have non intra-branch pull requests
repos.with.intrabranch <- aggregate(pull_req_id~project_name, subset(a, intra_branch == T), length)
repos.with.intrabranch <- rename(repos.with.intrabranch, c("pull_req_id"="intra_branch_pullreqs"))

repos <- merge(repos, repos.with.intrabranch, by="project_name", all.x = T)

# The above merge is a left outer join, so NA values might appear
repos$intra_branch_pullreqs <-
  apply(repos, 1, function(x){
    if(is.na(x[9])){
      0
    } else{
      as.integer(x[9])
    }
  })

repos$intrabranch_criterion <- repos$pr_extracted > (repos$intra_branch_pullreqs)

#3. Remove lowest 5% projects by merge ratio
merged <- aggregate(pull_req_id~project_name, subset(a, !is.na(merged_at)), length)
merged <- rename(merged, c("pull_req_id" = "merged"))
repos <- merge(repos, merged, by="project_name", all.x = T)

repos$merged <-
  apply(repos, 1, function(x){
    if(is.na(x['merged'])){
      0
    } else{
      as.numeric(x['merged'])
    }
  })

repos$merge_ratio <-
  apply(repos, 1, function(x) {
    if(as.numeric(x['pr_extracted']) == 0){
      0
    } else {
      as.numeric(x['merged']) / as.numeric(x['pr_extracted'])
    }
  })

five.perc <- quantile(repos$merge_ratio, 0.05, na.rm = T)
repos$merge_criterion <- as.logical(repos$merge_ratio > five.perc)

# Finally the results
include <- unique(subset(repos, completeness_criterion == T & merge_criterion == T)$project_name)
all <- all[all$project_name %in% as.vector(include),]

printf("Total projects: %d, total pullreqs: %d", length(include), nrow(all))

out <- "Filtered out %d projects,
          %d failed to build properly,
          %d had too low merge ratio,
          %d had both of the above"
printf(unwrap(out), 
       length(unique(subset(repos, completeness_criterion == F | merge_criterion == F)$project_name)),
       length(unique(subset(repos, completeness_criterion == F)$project_name)),
       length(unique(subset(repos, merge_criterion == F)$project_name)),
       length(unique(subset(repos, merge_criterion == F & merge_criterion == F)$project_name)))

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
