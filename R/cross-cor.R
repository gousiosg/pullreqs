#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

rm(list = ls(all = TRUE))

source(file = "R/packages.R")
source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(ellipse)
library(ggplot2)
library(reshape)

columns = c('lifetime_minutes', 'mergetime_minutes',
            'num_commits', 'src_churn', 'test_churn',
            'files_added',
              #'files_deleted',
            'files_modified', 'files_changed', 'src_files',
            'doc_files', 'other_files',
            'num_commit_comments', 'num_issue_comments','num_comments',
            'num_participants',
            'sloc', 'team_size',
            'perc_external_contribs', 'commits_on_files_touched',
            'test_lines_per_kloc', 'test_cases_per_kloc', 'asserts_per_kloc',
            'watchers',
            'prev_pullreqs', 'requester_succ_rate', 'followers')

all <- load.data(project.list)
used <- subset(all, select=columns)

# Cross correlation ellipses
ctab <- cor(used, method = "spearman", use='complete.obs')
colorfun <- colorRamp(c("#ff0000","white","#0000ff"), space="rgb")
store.pdf(plotcorr(ctab,
                   col=rgb(colorfun((ctab+1)/2), maxColorValue=255),
                   outline = FALSE),
          plot.location,"cross-cor.pdf")
dev.off()

# Cross correlation table
print(xtable(ctab,
             caption="Cross correlation matrix (Spearman) between examined factors",
             label="tab:crosscor"),
         type = "latex",
         size = "small",
         file = paste(latex.location, "cross-cor.tex", "/"))

# Cross correlation heatmap
ctab.m <- melt(ctab)
p <- ggplot(ctab.m, aes(X1, X2, fill = value)) +
  geom_tile() +
  scale_fill_gradient2(space = "Lab") +
  theme(axis.title = element_blank(),
        axis.text = element_text(size = 11),
        axis.text.x = element_text(angle = -90, hjust = 0, vjust = 0.5))
store.pdf(p, plot.location, "cross-cor-heat.pdf")


