rm(list = ls(all = TRUE))

source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(digest)
library(xtable)

descr.stats <- data.frame(
  Feature = c('lifetime_minutes',
              'mergetime_minutes',
              #'merged_using',
              'num_commits',
              'src_churn',
              'test_churn',
              'files_added',
              #'files_deleted',
              'files_modified',
              'files_changed',
              'src_files',
              'doc_files',
              'other_files',
              'num_commit_comments',
              'num_issue_comments',
              'num_comments',
              'num_participants',
              #'conflict',
              #'forward_link',
              #'intra_branch',
              'sloc',
              'team_size',
              'perc_external_contribs',
              'commits_on_files_touched',
              'test_lines_per_kloc',
              'test_cases_per_kloc',
              'asserts_per_kloc',
              'watchers',
              'prev_pullreqs',
              'requester_succ_rate',
              'followers'),
              #'main_team_member'),
  Description = c(
    "Minutes between opening and closing a pull request",
    "Minutes between opening and merging a pull request (only for merged pull
    requests)",
    #"Heuristic used for detecting pull request merge",
    "Number of commits in the pull request",
    "Number of lines changed (added + deleted) by the pull request.",
    "Number of test lines changed in the pull request.",
    "Number of files added by the pull request",
    #"Number of files deleted by the pull request",
    "Number of files modified by the pull request",
    "Number of files touched by the pull request (sum of the above three)",
    "Number of source code files touched by the pull request",
    "Number of documentation (markup) files touched by the pull request",
    "Number of non-source, non-documentation files touched by the pull request",
    "The total number of code review comments in the pull request.",
    "The total number of discussion comments in the pull request",
    "The total number of comments (discussion and code review).",
    "Number of participants in the pull request discussion",
    #"The word conflict appears in the pull request comments.",
    #"The pull request comments include links to other pull requests.",
    #"The pull request is between branches in the same repository",
    "Executable lines of code at pull request creation time.",
    "Number of active core team members during the last 3 months prior the pull request creation.",
    "The ratio of commits from external members over core team members in the last 3 months prior to pull request creation.",
    "Number of total commits on files touched by the pull request 3 months before the pull request creation time.",
    "Executable lines of test code per 1000 lines of source code",
    "Number of test cases per 1000 lines of source code",
    "Number of assert statements per 1000 lines of source code",
    "Project watchers (stars) at the time the pull request was opened",
    "Number of pull requests submitted by a specific developer, prior to the examined pull request.",
    "The percentage of the developer's pull requests that have been merged up to the creation of the examined pull request.",
    "Followers to the developer at the time the pull request was made"
    #"Whether the developer belongs to the main repository team.",
  )
)

all <- load.data(project.list)

descr.stats$Feature <- as.character(descr.stats$Feature)
descr.stats$quant_5 <- lapply(descr.stats$Feature, function(x){quantile(all[,x], 0.05,na.rm = T)})
descr.stats$mean <- lapply(descr.stats$Feature, function(x){mean(all[,x], na.rm = T)})
descr.stats$median <- lapply(descr.stats$Feature, function(x){median(all[,x], na.rm = T)})
descr.stats$quant_95 <- lapply(descr.stats$Feature, function(x){quantile(all[,x], 0.95, na.rm = T)})
descr.stats$histogram <- lapply(descr.stats$Feature, function(x) {
  print(sprintf("Histogram for %s", x))
  data <- all[, x]
  unq <- digest(sprintf("descr.stats.%s",as.character(x)))
  fname <- paste(plot.location, sprintf("hist-%s.pdf",unq), sep="/")

  par(mar=c(0,0,0,0))
  plot.window(c(0,1),c(0,1),  xaxs='i', yaxs='i')
  pdf(file = fname , width = 6, height = 3)
  hist(log(data), probability = TRUE, col = "red", border = "white",
       breaks = 10, xlab = "", ylab = "", axes = F, main = NULL)
  dev.off()
  sprintf("\\includegraphics[scale = 0.1, clip = true, trim= 50px 60px 50px 60px]{hist-%s.pdf}", unq)
})

table <- xtable(descr.stats, label="tab:features",
                caption="Selected features and descriptive statistics. Historgrams are in log scale.",
                align = c("l", "r","p{16em}", rep("r", 4), "c"))

print.xtable(table, file = paste(latex.location, "feature-stats.tex", sep = "/"),
             floating.environment = "table*",
             include.rownames = F, size = c(-2),
             sanitize.text.function = function(str)gsub("_","\\_",str,fixed=TRUE))
