library(RMySQL)
library(ggplot2)

source(file = "R/variables.R")
source(file = "R/mysql.R")

print("Running database queries...")
con <- dbConnect(dbDriver("MySQL"), user = mysql.user, password = mysql.passwd, 
                 dbname = mysql.db, host = mysql.host)

# Overall project statistics
if (file.exists(overall.dataset.stats)) {
  print(sprintf("%s file found", overall.dataset.stats))
  projectstats <- read.csv(file = overall.dataset.stats)
} else {
  print(sprintf("File not found %s", overall.dataset.stats))
  print("Running project stats query, this will take long...")
  # This will take a LONG time. Think >0.5 hours.
  res <- dbSendQuery(con, "select concat(u.login, '/', p.name) as name, (select count(*) from commits c, project_commits pc where pc.project_id = p.id and pc.commit_id = c.id) as commits, (select count(*) from watchers where repo_id = p.id) as watchers, (select count(*) from pull_requests where base_repo_id = p.id) as pull_requests, (select count(*) from issues where repo_id = p.id) as issues, (select count(*) from project_members where repo_id = p.id) as project_members, (select count(distinct c.author_id) from commits c, project_commits pc where pc.project_id = p.id and pc.commit_id = c.id) as contributors, (select count(*) from projects p1 where p1.forked_from = p.id) as forks, (select count(*) from issue_comments ic, issues i where ic.issue_id=i.id and i.repo_id = p.id) as issue_comments, (select count(*) from pull_requests pr, pull_request_comments prc where pr.base_repo_id=p.id and prc.pull_request_id = pr.id) as pull_req_comments, p.language from projects p, users u where p.forked_from is null and u.id = p.owner_id group by p.id  order by watchers desc;")
  projectstats <- fetch(res, n = -1)
  save.csv(projectstats, file = overall.dataset.stats)
  projectstats
}

# Total repos
res <- dbSendQuery(con, "select count(*) as cnt from projects")
repos <- fetch(res, n = -1)
print(sprintf("Total repos: %d",repos$cnt))

# Total users
res <- dbSendQuery(con, "select count(*) as cnt from users")
users <- fetch(res, n = -1)
print(sprintf("Total repos: %d",repos$cnt))

# Original repos
res <- dbSendQuery(con, "select count(*) as cnd from projects where forked_from is null and name not regexp '^.*\.github\.com$' and name <> 'try_git' and name <> 'dotfiles'")
orig_repos <- fetch(res, n = -1)
print(sprintf("Original repos: %f",orig_repos$cnt))

# % of original repos 
print(sprintf("Original repos: %f",(orig_repos$cnt/repos$cnt) * 100)

# Original repositories that received a single commit
res <- dbSendQuery(con, "select count(*) as cnt from projects p where forked_from is null and name not regexp "^.*\.github\.com$" and name <> 'try_git' and name <> 'dotfiles' and exists ( select * from project_commits pc, commits c where  pc.project_id = p.id and  c.id = pc.commit_id and year(c.created_at) = 2012)")
repos_with_commits <- fetch(res, n = -1)
print(sprintf("Original repos with commits: %f", repos_with_commits$cnt)

# % of active repos (original repos with a commit in 2012)
print(sprintf("Original repos with commits: %f",(repos_with_commits$cnt/repos$cnt) * 100)

# Total pull requests
res <- dbSendQuery(con, "select count(*) from pull_requests as cnt")
pullreqs <- fetch(res, n = -1)
print(sprintf("Total pull requests: %f",pullreqs$cnt))


# % of pull req comments by non-repo members 
res <- dbSendQuery(con, "select count(pr.id) as cnt from pull_requests pr, pull_request_comments prc where pr.id = prc.pull_request_id and not exists (select * from project_commits pc, commits c where pc.commit_id = c.id and pc.project_id = pr.base_repo_id and c.author_id = prc.user_id);")
prc_non_members <- fetch(res, n = -1)
print(sprintf("Pull request comments by non project members: %f", prc_non_members$cnt)

# % of pull req comments by non-repo members 
print(sprintf("% comments from non-repo members: %f",(prc_non_members$cnt/pullreqs$cnt) * 100)

# Pull req comments
res <- dbSendQuery(con, "select i.pr_id, ic_cnt + prc_cnt as cnt from (select pr.id as pr_id, count(*) as ic_cnt from projects p, pull_requests pr, issues i, issue_comments ic where p.forked_from is null and pr.base_repo_id = p.id and i.id = ic.issue_id and pr.id = i.pull_request_id group by pr.id) as i, (select pr.id as pr_id, count(*) as prc_cnt  from projects p, pull_requests pr, pull_request_comments prc  where p.forked_from is null and p.id = pr.base_repo_id and prc.pull_request_id = pr.id  group by pr.id) as pr where pr.pr_id = i.pr_id")
prs <- fetch(res, n = -1)
print(sprintf("Num discussion comments per pulreq (mean): %f", mean(prs$cnt)))
print(sprintf("Num discussion comments per pulreq (95 perc): %d", quantile(prs$cnt, 0.95)))
print(sprintf("Num discussion comments per pulreq (5 perc): %d", quantile(prs$cnt, 0.05)))

# Original repos that received a pullreq in 2012
res <- dbSendQuery(con, "select count(*) as cnt from projects p where p.forked_from is null  and p.name not regexp '^.*\.github\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and exists (select pr.id from pull_requests pr, pull_request_history prh where pr.base_repo_id = p.id and prh.pull_request_id = pr.id and year(prh.created_at)=2012)")
orig_repos_pullreqs <- fetch(res, n = -1)
print(sprintf("Repos that received a pull request in 2012: %s", orig_repos_pullreqs$cnt))
print(sprintf("% repos that received a pull request in 2012: %s", orig_repos_pullreqs$cnt/orig_repos$cnt) * 100)

# Pull request statistics and histogram for pull reqs in 2012
res <- dbSendQuery(con, "select pr.base_repo_id as repoid, count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles'  and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='opened' and year(prh.created_at)=2012)  group by pr.base_repo_id order by count(*) desc")
pullreqs <- fetch(res, n = -1)
print(sprintf("Pullreqs per project (mean): %f", mean(pullreqs$cnt)))
print(sprintf("Pullreqs per project (95 perc): %d", quantile(pullreqs$cnt, 0.95)))
print(sprintf("Pullreqs per project (5 perc): %d", quantile(pullreqs$cnt, 0.05)))
store.pdf(qplot(cnt, data = subset(pullreqs, cnt > 10), geom = "histogram", log = "x", ylab = "Number of projects", xlab = "Number of pull requests (log)"), plot.location, "pull-req-freq.pdf")
      
# Overall pull req stats - opened
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles'  and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='opened' and year(prh.created_at)=2012)")
opened_pullreqs <- fetch(res, n = -1)$cnt

# Overall pull req stats - closed
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles'  and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='closed' and year(prh.created_at)=2012)")
closed_pullreqs <- fetch(res, n = -1)$cnt

# Overall pull req stats - merged
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles'  and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='merged' and year(prh.created_at)=2012)")
merged_pullreqs <- fetch(res, n = -1)$cnt
print(sprintf("Perc merged pull requests: %f", (merged_pullreqs/opened_pullreqs) * 100))

# Correlation between pull requests and watchers
have.pr = subset(projectstats, pull_requests >0 & watchers > 0)
cor_pr_watch <- cor.test(have.pr$pull_requests, have.pr$watchers, method="kendall")
print(sprintf("Kendall correlation pullreqs-watchers: %f (n = %d, p = %f)", cor_pr_watch$estimate, length(have.pr$pull_requests), cor_pr_watch$p.value))
      
# Forked repos
res <- dbSendQuery(con, "select count(*) as cnt from projects where forked_from is not null")
forked_repos <- fetch(res, n = -1)
print(sprintf("Perc forked repos: %f", (forked_repos/repos) * 100))

# Drive-by commits pull reqs
res <- dbSendQuery(con, "select count(*) as cnt from pull_requests pr, pull_request_history prh where prh.action = 'opened' and prh.pull_request_id = pr.id and year(prh.created_at) = 2012 and not exists (select c.author_id from commits c, project_commits pc where pc.project_id = pr.base_repo_id and c.created_at < prh.created_at and c.author_id = pr.user_id) and 1 = (select count(*) from pull_request_commits prc where prc.pull_request_id = pr.id)")
drive_by_pr <- fetch(res, n = -1)$cnt
print(sprintf("Perc drive by pull requests: %f", (drive_by_pr/opened_pullreqs) * 100))
print(sprintf("Perc one pull req repos: %f", (drive_by_pr/forked_repos) * 100))
      
# Pull req size stats: number of commits
res <- dbSendQuery(con, "select pr.id, count(*) as cnt from pull_requests pr, pull_request_commits prc where prc.pull_request_id = pr.id group by pr.id")
pr_stats_num_commit <- fetch(res, n = -1)
