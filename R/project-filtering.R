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

# Load the top-level project list
a <- load.data("projects.txt")

# Apply exclusion criteria
#1. Should have more that 80 pullreqs
q <- "select project_name, count(*) cnt from a group by project_name"
pullreq.counts <- sqldf(q, drv="SQLite", row.names=F)

repos$extracted_pullreqs <- 
  apply(repos, 1, function(x) {
    
  })

repos$completeness_criterion <- 
  apply(repos, 1, function(x){
    name = sprintf("%s/%s", x[1], x[2])
    num.pullreqs <- subset(pullreq.counts, project_name == name)
    num.pullreqs <- if (nrow(num.pullreqs) == 0){0}else{num.pullreqs$cnt}
    printf("name: %s pullreqs in database: %d, extracted: %s",name, num.pullreqs, x[5])
    if (x[5] > num.pullreqs * 0.8 ) {
      FALSE
    } else {
      TRUE
    }
  })

#a <- a[!a$project_name %in% as.vector(less.than.80$project_name),]

#3. Should have non intra-branch pull requests
q <- "select distinct(project_name) 
      from a a1 where not exists (
        select * 
        from a a2 
        where a2.project_name = a1.project_name and a2.intra_branch is 1)"
only.intra_branch <- sqldf(unwrap(q), drv="SQLite", row.names=F)
a <- a[a$project_name %in% as.vector(only.intra_branch$project_name),]

#4. Merge percentage should mean + 1 stdev
q <- "select project_name, 
        (select count(*) 
        from a a1 
        where a1.project_name = a.project_name and merged = 'TRUE') * 1.0 / 
        (select count(*) 
        from a a1 
        where a1.project_name = a.project_name) as ratio_merged 
      from a 
      group by project_name 
      order by ratio_merged"

repos.mergeratio <- sqldf(unwrap(q), drv="SQLite", row.names=F)
a <- a[!a$project_name %in% as.vector(less.than.50.mergeratio$project_name),]

out <- "Filtered out %d projects
          %d had < 80 pullreqs, 
          %d did not have tests, 
          %d did only had intra-branch pullreqs, 
          %d had merge ratio < 0.5"
printf(out, nrow(rbind(less.than.80, no.tests, only.intra_branch, less.than.50.mergeratio)),
       nrow(less.than.80), nrow(no.tests), 
       nrow(only.intra_branch), nrow(less.than.50.mergeratio))



# merged.perc$order = as.numeric(rownames(merged.perc))
# p <- ggplot(merged.perc, aes(x = order, y = ratio_merged)) +
#   geom_bar(stat="identity", color = "#ff3333") +
#   theme(axis.text.x=element_blank()) +
#   ylab("Percentage") +
#   xlab("Project")
# store.pdf(p, plot.location, 'perc-merged.pdf')
