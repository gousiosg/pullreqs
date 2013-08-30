rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/utils.R")
source(file = "R/variables.R")
source(file = "R/mysql.R")

library(RMySQL)
library(ggplot2)
library(reshape)
library(sqldf)

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
  res <- dbSendQuery(con, "select concat(u.login, '/', p.name) as name, (select count(*) from commits c, project_commits pc    where pc.project_id = p.id and pc.commit_id = c.id) as commits, (select count(*) from watchers where repo_id = p.id) as watchers, (select count(*) from pull_requests where base_repo_id = p.id)   as pull_requests, (select count(*) from issues where repo_id = p.id) as issues, (select count(*)    from project_members where repo_id = p.id) as project_members, (select count(distinct c.author_id)  from commits c, project_commits pc where pc.project_id = p.id and pc.commit_id = c.id) as contributors, (select count(*) from projects p1 where p1.forked_from = p.id) as forks, (select count(*) from issue_comments ic, issues i where ic.issue_id=i.id and i.repo_id = p.id) as issue_comments, (select count(*) from pull_requests pr, pull_request_comments prc where pr.base_repo_id=p.id and prc.pull_request_id = pr.id) as pull_req_comments, p.language from projects  p, users u where p.forked_from is null and p.deleted is false and u.id = p.owner_id group by p.id;")
  projectstats <- fetch(res, n = -1)
  write.csv(projectstats, file = overall.dataset.stats)
  projectstats
}

# Total repos
res <- dbSendQuery(con, "select count(*) as cnt from projects")
repos <- fetch(res, n = -1)
print(sprintf("Total repos: %d",repos$cnt))

# Total users
res <- dbSendQuery(con, "select count(*) as cnt from users")
users <- fetch(res, n = -1)
print(sprintf("Total users: %d",users$cnt))

# Original repos
res <- dbSendQuery(con, "select count(*) as cnt from projects where forked_from is null and name not regexp '^.*\\.github\\.com$' and name <> 'try_git' and name <> 'dotfiles' and name <> 'vimfiles'")
orig_repos <- fetch(res, n = -1)
print(sprintf("Original repos: %f",orig_repos$cnt))

# % of original repos 
print(sprintf("Original repos: %f",(orig_repos$cnt/repos$cnt) * 100))

# Original repositories that received a single commit in 2012
res <- dbSendQuery(con, "select count(*) as cnt from projects p where forked_from is null and name not regexp '^.*\\.github\\.com$' and name <> 'try_git' and name <> 'dotfiles' and name <> 'vimfiles' and exists ( select * from project_commits pc, commits c where  pc.project_id = p.id and  c.id = pc.commit_id and year(c.created_at) = 2012)")
repos_with_commits <- fetch(res, n = -1)
print(sprintf("Original repos with commits: %f", repos_with_commits$cnt))

# % of active repos (original repos with a commit in 2012)
print(sprintf("Original repos with commits: %f",(repos_with_commits$cnt/repos$cnt) * 100))

# Total pull requests
res <- dbSendQuery(con, "select count(*) as cnt from pull_requests")
pullreqs <- fetch(res, n = -1)
print(sprintf("Total pull requests: %d",pullreqs$cnt))

# % of pull req comments by non-repo members 
res <- dbSendQuery(con, "select count(pr.id) as cnt from pull_requests pr, pull_request_comments prc where pr.id = prc.pull_request_id and not exists (select * from project_commits pc, commits c where pc.commit_id = c.id and pc.project_id = pr.base_repo_id and c.author_id = prc.user_id);")
prc_non_members <- fetch(res, n = -1)
print(sprintf("Pull request comments by non project members: %f", prc_non_members$cnt))

# % of pull req comments by non-repo members 
print(sprintf("% comments from non-repo members: %f",(prc_non_members$cnt/pullreqs$cnt) * 100))

# Pull req comments
# The following takes a while, so here are the latest results
# [1] "Num discussion comments per pulreq (mean): 2.314321"
# [1] "Num discussion comments per pulreq (95 perc): 9"
# 80% = 3
# [1] "Num discussion comments per pulreq (5 perc): 0"         
res <- dbSendQuery(con, "select i.pr_id, ic_cnt + prc_cnt as cnt, i.issue_id from (select pr.id as pr_id, i.issue_id as issue_id, count(ic.comment_id) as ic_cnt from pull_requests pr left outer join issues i on pr.pullreq_id = i.issue_id left outer join issue_comments ic on i.id = ic.issue_id   where pr.base_repo_id = i.repo_id group by pr.id) as i, (select pr.id as pr_id, count(prc.comment_id) as prc_cnt  from projects p join pull_requests pr on p.id = pr.base_repo_id left outer join pull_request_comments prc on prc.pull_request_id = pr.id   where p.forked_from is null group by pr.id) as pr  where pr.pr_id = i.pr_id;")
prs <- fetch(res, n = -1)
print(sprintf("Num discussion comments per pulreq (mean): %f", mean(prs$cnt)))
print(sprintf("Num discussion comments per pulreq (95 perc): %d", quantile(prs$cnt, 0.95)))
print(sprintf("Num discussion comments per pulreq (5 perc): %d", quantile(prs$cnt, 0.05)))

# Original repos with > 1 committers and 0 pull reqs in 2012
res <- dbSendQuery(con, "select count(*) as cnt from projects p where forked_from is null and name not regexp '^.*\\.github\\.com$' and name <> 'try_git' and name <> 'dotfiles' and name <> 'vimfiles' and  (select count(c.author_id) from project_commits pc, commits c where  pc.project_id = p.id and  c.id = pc.commit_id and year(c.created_at) = 2012) > 1 and not exists (select pr.id from pull_requests pr, pull_request_history prh where pr.base_repo_id = p.id and prh.pull_request_id = pr.id and year(prh.created_at)=2012)")
repos_with_co_op_devs <- fetch(res, n = -1)$cnt
print(sprintf("Repos with > 1 committers and 0 pull reqs in 2012: %d", repos_with_co_op_devs))

# Original repos that received a pullreq in 2012
res <- dbSendQuery(con, "select count(*) as cnt from projects p where p.forked_from is null  and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and exists (select pr.id from pull_requests pr, pull_request_history prh where pr.base_repo_id = p.id and prh.pull_request_id = pr.id and year(prh.created_at)=2012)")
orig_repos_pullreqs <- fetch(res, n = -1)
print(sprintf("Repos that received a pull request in 2012: %s", orig_repos_pullreqs$cnt))
print(sprintf("Perc repos that received a pull request in 2012: %f", (orig_repos_pullreqs$cnt/repos_with_commits$cnt) * 100))

# Pull request statistics and histogram for pull reqs
res <- dbSendQuery(con, "select pr.base_repo_id as repoid, count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and p.name <> 'vimfiles'  and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='opened' and year(prh.created_at) > 2010)  group by pr.base_repo_id order by count(*) desc")
pullreqs <- fetch(res, n = -1)
print(sprintf("Pullreqs per project (mean): %f", mean(pullreqs$cnt)))
print(sprintf("Pullreqs per project (95 perc): %d", quantile(pullreqs$cnt, 0.95)))
print(sprintf("Pullreqs per project (5 perc): %d", quantile(pullreqs$cnt, 0.05)))
store.pdf(qplot(cnt, data = subset(pullreqs, cnt > 10), geom = "histogram", log = "x", ylab = "Number of projects", xlab = "Number of pull requests (log)"), plot.location, "pull-req-freq.pdf")

# Overall pull req stats - opened
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and p.name <> 'vimfiles'and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='opened' and year(prh.created_at)=2012)")
opened_pullreqs <- fetch(res, n = -1)$cnt

# Overall pull req stats - closed
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and p.name <> 'vimfiles' and pr.base_repo_id = p.id and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id and prh.action='closed' and year(prh.created_at)=2012)")
closed_pullreqs <- fetch(res, n = -1)$cnt

# Overall pull req stats - merged
res <- dbSendQuery(con, "select count(*) as cnt from projects p, pull_requests pr  where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and p.name <> 'vimfiles' and pr.base_repo_id = p.id and pr.merged = true and exists (select prh.created_at from pull_request_history prh where prh.pull_request_id = pr.id  and year(prh.created_at)=2012)")
merged_pullreqs <- fetch(res, n = -1)$cnt
print(sprintf("Perc merged pull requests: %f", (merged_pullreqs/opened_pullreqs) * 100))

# Pull reqs per month plot
res <- dbSendQuery(con, "select concat(year(prh.created_at), '-', month(prh.created_at), '-', '1') as timestamp, count(*) as cnt from pull_requests pr, pull_request_history prh where prh.pull_request_id = pr.id and prh.action = 'opened' group by  month(prh.created_at), year(prh.created_at) order by prh.created_at")
pullreqs_per_month <- fetch(res, n = -1)
pullreqs_per_month$month <- as.POSIXct(pullreqs_per_month$timestamp, origin = "1970-01-01")

store.pdf(ggplot(pullreqs_per_month, aes(x = month)) + 
  scale_x_datetime() + 
  geom_line(aes(y = cnt, colour = "1")) +
  stat_smooth(aes(y = cnt, color = "2"), method = "loess", formula = y ~ x^2, size = 1, alpha = 0) +
  xlab("Date") + 
  ylab("Number of pull requests per month")+
  scale_colour_manual(values=c("red", "blue"), labels = c("actual", "trend")) +
  theme(legend.title=element_blank()), plot.location,"num-pullreqs-month.pdf")
  

# Correlation between pull requests and watchers
have.pr = subset(projectstats, pull_requests >0 & watchers > 0)
cor_pr_watch <- cor.test(have.pr$pull_requests, have.pr$watchers, method="kendall")
print(sprintf("Kendall correlation pullreqs-watchers: %f (n = %d, p = %f)", cor_pr_watch$estimate, length(have.pr$pull_requests), cor_pr_watch$p.value))
cor_pr_watch <- cor.test(have.pr$pull_requests, have.pr$watchers, method="spearman")
print(sprintf("Spearman correlation pullreqs-watchers: %f (n = %d, p = %f)", cor_pr_watch$estimate, length(have.pr$pull_requests), cor_pr_watch$p.value))
      
# Forked repos
res <- dbSendQuery(con, "select count(*) as cnt from projects where forked_from is not null")
forked_repos <- fetch(res, n = -1)
print(sprintf("Perc forked repos: %f", (forked_repos/repos) * 100))

# Issue tracker % usage for projects 
res <- dbSendQuery(con, "select count(*) as cnt from projects p where p.forked_from is null and p.name not regexp '^.*\\.github\\.com$' and p.name <> 'try_git' and p.name <> 'dotfiles' and p.name <> 'vimfiles' and exists (select pr.id from pull_requests pr, pull_request_history prh where pr.base_repo_id = p.id and prh.pull_request_id = pr.id and year(prh.created_at)=2012) and exists (select i.id from issues i where i.repo_id = p.id and year(i.created_at)=2012)")
issue_pr_repos <- fetch(res, n = -1)
print(sprintf("Perc projects with pull reqs and issues (overall): %f", (issue_pr_repos/orig_repos) * 100))
print(sprintf("Perc projects with pull reqs and issues: %f", (issue_pr_repos/orig_repos_pullreqs) * 100))

# Commiter raise due to pull requests
# res <- dbSendQuery(con, "select p.id from projects p, users u, commits c, project_commits pc where p.forked_from is null and u.id = p.owner_id and pc.commit_id = c.id and pc.project_id = p.id  and exists (select c.id from project_commits pc, commits c where year(c.created_at) = 2012 and month (c.created_at)=12 and pc.commit_id = c.id and pc.project_id = p.id )  and exists (select c.id from project_commits pc, commits c where year(c.created_at) < 2007 and pc.commit_id = c.id and pc.project_id = p.id )  and exists (select pr.id from pull_requests pr, pull_request_history prh where prh.pull_request_id = pr.id and pr.base_repo_id = p.id and prh.action='opened' and year(prh.created_at) = 2010)  group by p.id having count(c.id) > 1000 order by p.created_at asc limit 200")
# Run the above query and handpick projects 
#      1334	rails	rails
#      3189	junit	KentBeck
#      6313	jquery	jquery
#      4367	phpbb3	phpbb
#      18716	rubygems	rubygems
#      9316	cakephp	cakephp
#      2602	monodevelop	mono
#      847	puppet	puppetlabs
#      5591	facter	puppetlabs
res <- dbSendQuery(con, "select p.name as project, last_day(c.created_at) as timestamp, count(distinct c.author_id) as num_authors from commits c, project_commits pc, projects p where pc.commit_id = c.id and pc.project_id = p.id and year(c.created_at) < 2013 and p.id in (3189, 6313, 4367, 18716, 9316, 2602, 847, 5591) group by p.id, month(c.created_at), year(c.created_at) order by p.name, year(c.created_at), month(c.created_at)")
devs_per_month <- fetch(res, n = -1)
devs_per_month$month <- as.POSIXct(devs_per_month$timestamp, origin = "1970-01-01")
store.pdf(ggplot(devs_per_month, aes(x = month, y = num_authors, colour = project)) + 
        scale_x_datetime() + 
        stat_smooth(method = "loess", formula = y ~ x^2, size = 1, alpha = 0) +
        annotate("pointrange", x = as.POSIXct(1283174614, origin = "1970-01-01"), ymin = 0, ymax = 20, y = 20) +
        annotate("text", x = as.POSIXct(1283174614, origin = "1970-01-01"), y = 20, label ="Github introduces pull requests", size = 4) +
        ylim(0, 22) + 
        xlab("Date") + 
        ylab("Number of active committers per month"), plot.location,"num-commiters-after-pr.pdf")

res <- dbSendQuery(con, "select a.project as project, avg(a.num_authors) as avg_after, avg(b.num_authors) as avg_before from (select p.id as project, last_day(c.created_at) as timestamp_after_pr, count(distinct c.author_id) as num_authors  from commits c, project_commits pc, projects p  where pc.commit_id = c.id and pc.project_id = p.id  and exists(select pc1.* from project_commits pc1, commits c1 where pc1.commit_id = c1.id and year(c1.created_at) = 2010 and month(c1.created_at) < 9 and pc1.project_id = p.id)   and c.created_at between makedate(2010, 213) and makedate(2011, 244) and p.forked_from is null group by p.id, month(c.created_at), year(c.created_at)) as a,  (select p.id as project, last_day(c.created_at) as timestamp_before_pr, count(distinct c.author_id) as num_authors from commits c, project_commits pc, projects p  where pc.commit_id = c.id and pc.project_id = p.id and exists(select pc1.* from project_commits pc1, commits c1 where pc1.commit_id = c1.id and year(c1.created_at) = 2010 and month(c1.created_at) < 9 and pc1.project_id = p.id) and c.created_at between makedate(2009, 244) and makedate(2010, 212) and p.forked_from is null group by p.id, month(c.created_at), year(c.created_at)) as b where a.project = b.project and exists(select pr.id from pull_requests pr, pull_request_history prh where pr.base_repo_id = a.project and prh.pull_request_id = pr.id and prh.created_at between makedate(2010, 213) and makedate(2011, 244)) group by a.project")
mean_commiters_per_month <- fetch(res, n = -1)
a <- subset(mean_commiters_per_month, avg_after > 2)
w <- wilcox.test(a$avg_after, a$avg_before, paired = TRUE)

print(sprintf("Wilcox: mean devs before/after pullreqs: n = %d, V = %f, p < %f", nrow(a), w$statistic, w$p.value))
print(sprintf("Cliff's delta on number of avg number of committers before/after pullreqs: %f", cliffs.d(a$avg_after, a$avg_before)))

ranksum(a$avg_after, a$avg_before)

# Drive-by commits pull reqs
res <- dbSendQuery(con, "select count(*) as cnt from pull_requests pr, pull_request_history prh where prh.action = 'opened' and prh.pull_request_id = pr.id and year(prh.created_at) = 2012 and not exists (select c.author_id from commits c, project_commits pc where pc.project_id = pr.base_repo_id and c.created_at < prh.created_at and c.author_id = pr.user_id) and 1 = (select count(*) from pull_request_commits prc where prc.pull_request_id = pr.id)")
drive_by_pr <- fetch(res, n = -1)$cnt
print(sprintf("Perc drive by pull requests: %f", (drive_by_pr/opened_pullreqs) * 100))
print(sprintf("Perc one pull req repos: %f", (drive_by_pr/forked_repos) * 100))    

# Load CSV files
dfs <- load.all(dir=data.file.location, pattern="*.csv$")
dfs <- addcol.merged(dfs)
all <- merge.dataframes(dfs)

# Discussion comments from internal vs externals
project_ids <- lapply(unique(all$project_name), function(x) {
  printf("Aquiring id for project %s", x)
  details <- strsplit(as.character(x),'/')[[1]]
  res <- dbSendQuery(con, sprintf("select p.id from projects p, users u where u.id = p.owner_id and u.login = '%s' and p.name = '%s'", details[1], details[2]))
  fetch(res, n = -1)$id
})

comments <- data.frame()
for (pid in project_ids) {
  printf("Running for project %d ", pid)
  res <- dbSendQuery(con, sprintf("select a.p_id, concat(u.login, '/', p.name) as project_name, (select count(pm.user_id) from project_members pm where pm.user_id = a.user_id and pm.repo_id = a.p_id) as is_member,  count(distinct user_id) as num_users, sum(a.cnt) as num_comments  from (  (select pr.base_repo_id as p_id, ic.user_id as user_id, count(ic.comment_id) as cnt   from projects p join pull_requests pr on p.id = pr.base_repo_id left outer join issues i on pr.pullreq_id = i.issue_id left outer join issue_comments ic on i.id = ic.issue_id where p.forked_from is null and p.id = %d and pr.base_repo_id = i.repo_id group by pr.base_repo_id, ic.user_id)  union (select pr.base_repo_id as p_id, prc.user_id as user_id, count(prc.comment_id) as cnt    from projects p join pull_requests pr on p.id = pr.base_repo_id left outer join pull_request_comments prc on prc.pull_request_id = pr.id where p.forked_from is null and p.id = %d group by pr.base_repo_id, prc.user_id) ) as a, users u, projects p where p.owner_id = u.id and p.id = a.p_id group by a.p_id, is_member", pid, pid))
  d <- fetch(res, n = -1)
  comments <- rbind(comments, d)
  comments
}
      
comments <- subset(comments, num_users > 0 & num_comments >0)
processed_comments <- sqldf("select project_name, (select c1.num_users from comments c1 where c1.p_id = c.p_id and c1.is_member = 0)/sum(c.num_users) as commenters, (select c2.num_comments from comments c2 where c2.p_id = c.p_id and c2.is_member = 0)/sum(c.num_comments) as comments from comments c group by c.p_id", drv="SQLite")
processed_comments <- melt(processed_comments, 'project_name', na.rm = TRUE)
processed_comments$project_name <- as.factor(processed_comments$project_name)
processed_comments$value <- processed_comments$value * 100   

#processed_comments$foo <- match(processed_comments$value[processed_comments$variable == "comments"], sort(processed_comments$value[processed_comments$variable == "comments"]))
processed_comments$foo <- match(processed_comments$value[processed_comments$variable == "commenters"], sort(processed_comments$value[processed_comments$variable == "commenters"]))
processed_comments$foo <- as.factor(processed_comments$foo)
p <- ggplot(processed_comments, aes(x = foo, y = value, fill = variable)) + 
        scale_x_discrete() + xlab("Project") + ylab("%") +
        geom_bar(position="dodge") + 
        #theme(axis.text.x=element_text(angle = 90, size = 6), legend.position="none") +
        theme(axis.text.x=element_blank(), legend.position="none") +
        #ggtitle("% of external commenters/comments per project") +
        facet_grid(. ~ variable)
        
store.pdf(p, plot.location, "perc-external-commenters-comments.pdf")

# Various statistics on comments from community
mean_external_contribs <- aggregate(perc_external_contribs ~ project_name, all, mean)
joined <- merge(mean_external_contribs, processed_comments, by = "project_name")
a <- subset(joined, variable == "commenters", perc_external_contribs)
b <- subset(joined, variable == "comments", value)
cor.test(a$perc_external_contribs, b$value, method="spearman")

b <- subset(joined, variable == "commenters", value)
cor.test(a$perc_external_contribs, b$value, method="spearman")

nrow(subset(processed_comments, variable == "commenters" & value > 50))

###
# Overall statistics table
cache <- new.env()

data <- data.frame(
  description = c('Number of participants', 'Number of comments', 'Number of commits', 'Time to merge', 'Time to close'),
  query = c(
    "select (select count(distinct(prh.actor_id)) from pull_request_history prh where prh.pull_request_id = pr.id) +  (select count(distinct(ie.actor_id)) from issue_events ie, issues i where i.id = ie.issue_id and i.pull_request_id = pr.id) as participants from pull_requests pr group by id;",
    "select (select count(*)  from issue_comments ic, issues i where ic.issue_id = i.id and i.pull_request_id = pr.id) +  (select count(*) from pull_request_comments prc where prc.pull_request_id = pr.id ) as num_comments from pull_requests pr group by pr.id;",
    "select count(*) as number_of_commits from pull_request_commits group by pull_request_id;",
    "select timestampdiff(minute, a.created_at, b.created_at) as mergetime_minutes from pull_request_history a, pull_request_history b where a.action = 'opened' and b.action ='merged' and a.pull_request_id = b.pull_request_id group by a.pull_request_id;",
    "select timestampdiff(minute, a.created_at, b.created_at) as lifetime_minutes from pull_request_history a, pull_request_history b where a.action = 'opened' and b.action ='closed'  and not exists (select * from pull_request_history c where c.pull_request_id = a.pull_request_id and c.action = 'merged') and a.pull_request_id = b.pull_request_id group by a.pull_request_id;"
  )
)

do.query <- function(con, cache, x) {
  library(digest)
  print(x)
  md5 <- digest(x)
  if (is.null(cache[[md5]])) {
    res <- dbSendQuery(con, x)
    r <- fetch(res, n = -1)[[1]]
    cache[[md5]] <- r
  }
  cache[[md5]]
}

fix <- function(x) {
  if(x < 0) {
    0
  } else {
    x
  }
}

data$min <- lapply(data$query, function(x){fix(min(do.query(con, cache, as.character(x))))})
data$quant_5 <- lapply(data$query, function(x){fix(quantile(do.query(con, cache, as.character(x)),0.05))})
data$quant_50 <- lapply(data$query, function(x){fix(quantile(do.query(con, cache, as.character(x)),0.50))})
data$median <- lapply(data$query, function(x){fix(median(do.query(con, cache, as.character(x))))})
data$mean <- lapply(data$query, function(x){fix(mean(do.query(con, cache, as.character(x))))})
data$quant_95 <- lapply(data$query, function(x){fix(quantile(do.query(con, cache, as.character(x)),0.95))})
data$max <- lapply(data$query, function(x){fix(max(do.query(con, cache, as.character(x))))})
