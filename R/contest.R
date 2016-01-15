library(data.table)

printf <- function(...) invisible(print(sprintf(...)))

load.filter <- function(path) {
  setAs("character", "POSIXct",
        function(from){as.POSIXct(from, origin = "1970-01-01")})
  
  a <- read.csv(path, check.names = T, 
                colClasses = c(
                  "integer",      #pull_req_id
                  "factor",       #project_name
                  "factor",       #lang
                  "integer",      #github_id
                  "integer",      #created_at
                  "integer",      #merged_at
                  "integer",      #closed_at
                  "integer",      #lifetime_minutes
                  "integer",      #mergetime_minutes
                  "factor",       #merged_using
                  "factor",       #conflict
                  "factor",       #forward_links
                  "factor",       #intra_branch
                  "integer",      #description_length
                  "integer",      #num_commits
                  "integer",      #num_commits_open
                  "integer",      #num_pr_comments
                  "integer",      #num_issue_comments
                  "integer",      #num_commit_comments
                  "integer",      #num_comments
                  "integer",      #num_commit_comments_open
                  "integer",      #num_participants
                  "integer",      #files_added_open
                  "integer",      #files_deleted_open
                  "integer",      #files_modified_open
                  "integer",      #files_changed_open
                  "integer",      #src_files_open
                  "integer",      #doc_files_open
                  "integer",      #other_files_open
                  "integer",      #files_added
                  "integer",      #files_deleted
                  "integer",      #files_modified
                  "integer",      #files_changed
                  "integer",      #src_files
                  "integer",      #doc_files
                  "integer",      #other_files
                  "integer",      #src_churn_open
                  "integer",      #test_churn_open
                  "integer",      #src_churn
                  "integer",      #test_churn
                  "numeric",      #new_entropy
                  "numeric",      #entropy_diff
                  "integer",      #commits_on_files_touched
                  "integer",      #commits_to_hottest_file
                  "numeric",      #hotness
                  "integer",      #at_mentions_description
                  "integer",      #at_mentions_comments
                  "numeric",      #perc_external_contribs
                  "integer",      #sloc
                  "numeric",      #test_lines_per_kloc
                  "numeric",      #test_cases_per_kloc
                  "numeric",      #asserts_per_kloc
                  "integer",      #stars
                  "integer",      #team_size
                  "integer",      #workload
                  "factor",       #ci
                  "factor",       #requester
                  "factor",       #closer
                  "factor",       #merger
                  "integer",      #prev_pullreqs
                  "numeric",      #requester_succ_rate
                  "integer",      #followers
                  "factor",       #main_team_member
                  "factor",       #social_connection
                  "integer",      #prior_interaction_issue_events
                  "integer",      #prior_interaction_issue_comments
                  "integer",      #prior_interaction_pr_events
                  "integer",      #prior_interaction_pr_comments
                  "integer",      #prior_interaction_commits
                  "integer",      #prior_interaction_commit_comments
                  "integer"      #first_response
                )
  )
  
  a$prior_interaction_comments <- a$prior_interaction_issue_comments + a$prior_interaction_pr_comments + a$prior_interaction_commit_comments
  a$prior_interaction_events <- a$prior_interaction_issue_events + a$prior_interaction_pr_events + a$prior_interaction_commits
  
  a$has_ci <- a$ci != 'unknown'
  a$has_ci <- as.factor(a$has_ci)
  
  a$merged <- !is.na(a$merged_at)
  a$merged <- as.factor(a$merged)
  #   # Take care of cases where csv file production was interupted, so the last
  #   # line has wrong fields
  a <- subset(a, !is.na(first_response))
  data.table(a)
}


load.all <- function(dir = ".", pattern = "*.csv$",
                     projects.file = "projects.txt") {
  
  to_load <- which.to.load(dir, pattern, projects.file)
  
  l <- foreach(x = to_load, .combine=c) %dopar% {
    if (file.exists(x)) {
      print(sprintf("Reading file %s", x))
      
      a <- tryCatch(load.filter(x), 
                    error = function(e){print(e); data.table()})
      if (nrow(a) == 0) {
        printf("Warning - No rows in file %s", x)
        list()
      } else {
        list(a)
      }
    } else {
      printf("File does not exist %s", x)
      list()
    }
  }
  
  rbindlist(l)
}

which.to.load <- function(dir = ".", pattern = "*.csv$",
                          projects.file = "projects.txt") {
  if(file.exists(projects.file)) {
    joiner <- function(x){
      owner <- x[[1]]
      repo <- x[[2]]
      sprintf("%s/%s@%s.csv", dir, owner, repo)
    }
    apply(read.csv(projects.file, sep = " ", header=FALSE), c(1), joiner)
  } else {
    list.files(path = dir, pattern = pattern, full.names = T)
  }
}

all <- load.all(dir = 'data')

all$process_speed <- apply(all, 1, function(x) {
  lifetime_minutes <- as.integer(x[8])
  if (lifetime_minutes < 60) {
    return("FAST")
  } else if (lifetime_minutes > 60 && lifetime_minutes < 24* 60 ) {
    return("MEDIUM")
  } else {
    return("SLOW")
  }
})

all$process_speed <- as.factor(all$process_speed)

setkey(all, project_name, github_id, requester)
all$pr_ratio <- apply(all, 1, function(x) {
  pname  <- x[2]
  pr_num <- as.integer(x[4])
  dev    <- x[57]

  project_prs <- all[.(pname)]

  prev_prs <- nrow(project_prs[github_id %between% c(0, pr_num)])
  requester_prev_prs <- nrow(project_prs[requester == dev & github_id %between% c(0, pr_num)])

  requester_prev_prs / prev_prs

})

all.contest<- data.frame(all)[,
    c('project_name', 'lang','github_id', 'intra_branch',
      'description_length','num_commits_open','num_commit_comments_open',
      'files_added_open','files_deleted_open','files_modified_open',
      'files_changed_open','src_files_open','doc_files_open','other_files_open',
      'src_churn_open','test_churn_open','new_entropy','entropy_diff',
      'commits_on_files_touched','commits_to_hottest_file','hotness',
      'at_mentions_description','perc_external_contribs','test_lines_per_kloc',
      'test_cases_per_kloc','asserts_per_kloc','team_size','workload', 
      'pr_ratio', 'prev_pullreqs','requester_succ_rate','followers',
      'main_team_member', 'social_connection','prior_interaction_comments',
      'prior_interaction_events','has_ci', 'process_speed', 'merged')]

write.csv(all.contest, file = 'data.csv')
