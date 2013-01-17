library(RMySQL)
source(file = "R/variables.R")
source(file = "R/mysql.R")

con <- dbConnect(dbDriver("MySQL"), user = mysql.user, password = mysql.passwd, 
                 dbname = mysql.db, host = mysql.host)

res <- dbSendQuery(con, "select pr.id as pr, count(*) as cnt from pull_requests pr, pull_request_comments prc where prc.pull_request_id = pr.id group by pr.id")
prs <- fetch(res, n = -1)

print(sprintf("Num discussion comments per pulreq (mean): %f", mean(prs$cnt)))
print(sprintf("Num discussion comments per pulreq (95th perc): %d", quantile(prs$cnt, 0.95)))

# Overall project statistics
if (file.exists(overall.dataset.stats)) {
  print(sprintf("%s file found", overall.dataset.stats))
  projectstats <- read.csv(file = overall.dataset.stats)
} else {
  print(sprintf("File not found %s", overall.dataset.stats))
  # This will take a LONG time. Think >10 hours.
  #res <- dbSendQuery(con, "select concat(u.login, '/', p.name) as owner, (select count(*) from commits c, project_commits pc where pc.project_id = p.id and pc.commit_id = c.id) as commits, (select count(*) from watchers where repo_id = p.id) as watchers, (select count(*) from pull_requests where base_repo_id = p.id) as pull_requests, (select count(*) from issues where repo_id = p.id) as issues, (select count(*) from project_members where repo_id = p.id) as project_members, (select count(distinct c.author_id) from commits c, project_commits pc where pc.project_id = p.id and pc.commit_id = c.id) as contributors, p.language from projects p, users u where not exists (select forked_from_id from forks where forked_project_id = p.id) and u.id = p.owner_id group by p.id  order by commits desc;")
  #projectstats <- fetch(res, n = -1)
  #save.csv(projectstats, file = overall.dataset.stats)
  projectstats
}



sample <- projectstats[sample(which(projectstats$language=="Ruby" & projectstats$contributors > projectstats$project_members & projectstats$project_members > 0 & projectstats$pull_requests > 0), 50, replace = FALSE), ]
