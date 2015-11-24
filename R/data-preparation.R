rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(plyr)
library(RMySQL)
library(caret)
library(doMC)
registerDoMC(cores = num.processes)

all <- load.all(dir = data.file.location)
numeric.fields <- c('description_length','num_commits_open','num_pr_comments',
                    'num_issue_comments','num_comments','num_commit_comments_open',
                    'num_participants','files_added_open','files_deleted_open',
                    'files_modified_open','files_changed_open','src_files_open',
                    'doc_files_open','other_files_open','src_churn_open',
                    'test_churn_open','new_entropy',
                    'entropy_diff','commits_on_files_touched',
                    'commits_to_hottest_file','hotness',
                    'at_mentions_description','at_mentions_comments',
                    'perc_external_contribs','sloc','test_lines_per_kloc',
                    'test_cases_per_kloc','asserts_per_kloc','stars',
                    'team_size','workload','prev_pullreqs','requester_succ_rate',
                    'followers','prior_interaction_comments',
                    'prior_interaction_events')

cross.cor <- all[, numeric.fields, with = F]

cor.table <- cor(cross.cor, method = "spearman")
#corrplot(cor.table, method="circle",order = "hclust", addrect = 2)

highly.correlated <- function(cor.table, threshold = "0.7") {
  cor.table[lower.tri(cor.table, diag = TRUE)] <- NA
  for(m in rownames(cor.table)) {
    for(n in rownames(cor.table)) {
      if (!is.na(cor.table[m, n]) && cor.table[m, n] >= threshold){
        printf("%s is highly correlated with %s", m, n)
      }
    }
  }
}

correlated <- findCorrelation(cor.table, cutoff = 0.75, exact = T, names = T)
printf("Removing highly correlated columns")
print(correlated)

all.1 <- all[, !correlated,  with = F]
numeric.fields <- setdiff(numeric.fields, correlated)

cross.cor <- all.1[, numeric.fields, with = F]

cor.table <- cor(cross.cor, method = "spearman")
#corrplot(cor.table, method="circle",order = "hclust", addrect = 2)


rm(cross.cor, cor.table, all.1)


