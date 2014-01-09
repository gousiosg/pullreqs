rm(list = ls(all = TRUE))

source(file = "R/cmdline.R")
source(file = "R/utils.R")

library(sqldf)

# Load the top-level project list
a <- load.data("projects.txt")

# Apply criteria
#1. Should have more that 80 pullreqs
q <- "select project_name from a group by project_name having count(*) < 80 "
less.than.80 <- sqldf(q, drv="SQLite", row.names=F)
a <- a[!a$project_name %in% as.vector(less.than.80$project_name),]

#2. Projects should have tests
q <- "select project_name 
      from a 
      group by project_name 
      having avg(test_lines_per_kloc) = 0"
no.tests <- sqldf(q, drv="SQLite", row.names=F)
a <- a[!a$project_name %in% as.vector(no.tests$project_name),]

#3. Should have non intra-branch pull requests
q <- "select distinct(project_name) 
      from a a1 where not exists (
        select * 
        from a a2 
        where a2.project_name = a1.project_name and a2.intra_branch is 1)"
only.intra_branch <- sqldf(unwrap(q), drv="SQLite", row.names=F)
a <- a[!a$project_name %in% as.vector(only.intra_branch$project_name),]

#4. Merge percentage should be > 50%
q <- "select project_name, 
        (select count(*) 
        from a a1 
        where a1.project_name = a.project_name and merged = 'TRUE') * 1.0 / 
        (select count(*) 
        from a a1 
        where a1.project_name = a.project_name) as ratio_merged 
      from a 
      group by project_name 
      having ratio_merged < 0.5
      order by ratio_merged"

less.than.50.mergeratio <- sqldf(unwrap(q), drv="SQLite", row.names=F)
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

# This is to check very low scores in merge % is due to the lack 
# of data as a result of the project not having an activated issue tracker
# check.has.bugs <- function(df, credentials = "username:password") {
#   has.bugs <- function(x) {
#     library(RCurl)
#     printf("Checking %s", x)
#     h = basicHeaderGatherer()
#     getURI(sprintf("https://api.github.com/repos/%s/issues", x),
#            userpwd=credentials,  httpauth = 1L, headerfunction = h$update)
#     h$value()['status'] == 200
#   }
#   df$has_bugs <- lapply(df$project_name, has.bugs)
# }

#check.has.bugs(merged.perc)
#rm(a)