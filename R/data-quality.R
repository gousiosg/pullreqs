rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(plyr)
library(RMySQL)

a <- load.all(dir = data.file.location)

# Checkout which files where not loaded
loaded.projects <- sort(unique(a$project_name))
projects.in.data.dir <- sort(
  sapply(
    list.files(path = data.file.location, pattern = '*.csv'), 
    function(path){gsub('.csv','', gsub('@','/', path))}
    )
  )

print("Not loaded project files")
print(setdiff(projects.in.data.dir, loaded.projects))

to.redo <- setdiff(projects.in.data.dir, loaded.projects)

# Compare PRs in dataset vs PRs in the DB
con <- dbConnect(dbDriver("MySQL"), user = mysql.user, password = mysql.passwd,
                 dbname = mysql.db, host = mysql.host)

prs.per.project <- aggregate(pull_req_id~project_name, a, length)
prs.per.project <- rename(prs.per.project, c("pull_req_id" = "prs.in.data"))

num.prs <- function(owner, repo, con) {
  printf("Querying num.prs for %s/%s", owner, repo)
  q <- "
    select count(*) as num_prs
    from pull_requests pr, projects p, users u
    where u.id = p.owner_id
    and pr.base_repo_id = p.id
    and u.login = '%s'
    and p.name = '%s'
  "
  res <- dbSendQuery(con, unwrap(sprintf(q, owner, repo)))
  fetch(res, n = -1)$num_prs
}

prs.per.project$prs.in.db <- apply(prs.per.project, 1, function(x) {
  num.prs(owner(x[1]), repo(x[1]), con)
})

prs.per.project$diff <- 100 - (prs.per.project$prs.in.data/prs.per.project$prs.in.db) * 100
printf("projects with lots of unbuild PRs")
subset(prs.per.project, diff >= 10)

# Projects where few tests where recognized
projects.few.test_lines <- subset(aggregate(test_lines_per_kloc~project_name + lang, a, mean), 
       test_lines_per_kloc < 100)

projects.few.asserts <- subset(aggregate(asserts_per_kloc~project_name + lang, a, mean), 
       asserts_per_kloc < 2)

projects.few.tests <- merge(projects.few.test_lines, projects.few.asserts)
printf("projects with few tests")
print(projects.few.tests$project_name)

# Hotness > 1 (!)
unique(subset(a, hotness > 1)$project_name)

# Various "This is just wrong!" conditions
total <- 0
r <- nrow(subset(a, num_commits < num_commits_open))
printf("Removing %d rows where num_commits < num_commits_open", r)
a <- subset(a, num_commits >= num_commits_open)
total <- total + r

r <- nrow(subset(a, num_commit_comments < num_commit_comments_open))
printf("Removing %d rows where num_commit_comments < num_commit_comments_open", r)
a <- subset(a, num_commit_comments >= num_commit_comments_open)
total <- total + r

r <- nrow(subset(a, files_added_open + files_deleted_open + files_changed_open > 
                    files_added + files_deleted + files_changed))
printf("Removing %d rows where files_*_open > files_*", r)
a <- subset(a, files_added_open + files_deleted_open + files_changed_open <= 
              files_added + files_deleted + files_changed)
total <- total + r

r <- nrow(subset(a, (src_files_open + doc_files_open + other_files_open > 
                   src_files + doc_files + other_files)))
printf("Removing %d rows where *_files_open > *_files", r)
a <- subset(a, (src_files_open + doc_files_open + other_files_open) <=
              (src_files + doc_files + other_files))
total <- total + r

# When the following happens, this means that the committed files are binary
r <- nrow(subset(a, a$new_entropy == 0 & a$num_commits_open > 0))
printf("Removing %d rows where entropy is 0 and num_commits_open is > 0", r)
a <- subset(a, !(new_entropy == 0 & a$num_commits_open >= 0))
total <- total + r

r <- nrow(subset(a, commits_on_files_touched < commits_to_hottest_file))
printf("Removing %d rows where commits_to_hottest_file > commits_on_files_touched", r)
a <- subset(a, commits_on_files_touched >= commits_to_hottest_file)
total <- total + r

printf("Removed %d number of rows from the dataset", total)

# Projects where the majority of PRs have team_size = 0
team.size.zero <- merge(aggregate(team_size~project_name, subset(a, team_size == 0), length),
      aggregate(team_size~project_name, a, length),
      by.x="project_name", by.y="project_name")

team.size.zero$ratio <- team.size.zero$team_size.x / team.size.zero$team_size.y
print("projects where team size is zero in > 0.05 % of the cases")
print(as.character(subset(team.size.zero, ratio > 0.05)$project_name))




