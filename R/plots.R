library(ggplot2)
library(igraph)

# Plot a stacked barchart displaying the proportion of merged/unmerged pull requests
plot.percentage.merged <- function(dfs) 
{
  a <- do.call(rbind, Map(function(x){
    total = nrow(x)
    merged = nrow(subset(x, x$merged_at > 0))
    unmerged_perc = (100 * (total - merged))/total
    merged_perc = 100 - unmerged_perc
    rbind(data.frame(project=unique(x[[1]][1]), status="merged", value=merged_perc),
      data.frame(project=unique(x[[1]][1]), status="unmerged", value=unmerged_perc))
  }, dfs))

  ggplot(a, aes(x=project, y =value, fill = status)) + 
    geom_bar(stat="identity", colour="white") +
    opts(axis.text.x=theme_text(angle=90, hjust = 1)) +
    ylab("Percentage")
}

# Plot various charts for selected projects 
data.accept.lifetime <- function(dfs, projects)
{
  do.call(rbind, Map(function(x){
    project = toString(unique(x[[1]][1]))
    if (trim(project) %in% projects) {
      merged = subset(x, x$merged_at > 0)
      data.frame(name=project, id=merged$github_id, lifetime=merged$lifetime_minutes)
    } else {
      data.frame(name=c(), id=c(), lifetime=c())
    }
  }, dfs)) 
}

plot.accept.lifetime.boxplot <- function(dfs, projects)
{
  ggplot(data.accept.lifetime(dfs, projects), aes(factor(name), lifetime)) +
    geom_boxplot() +
    ylim(0, 3000) +
    xlab("Project") +
    ylab("Lifetime (minutes)")
}

plot.accept.lifetime.freq <- function(dfs, projects)
{
  ggplot(data.accept.lifetime(dfs, projects), aes(x=lifetime, colour = name)) + 
    geom_density(alpha = 0.2) + 
    xlim(0, 10000) +
    xlab("Lifetime (minutes)") + 
    ylab("Probability")
}

plot.accept.lifetime.histogram <- function(dfs, projects)
{
  ggplot(data.accept.lifetime(dfs, projects), aes(x=lifetime, fill = name)) + 
    geom_bar() +
    xlim(0, 3000) +
    xlab("Lifetime (minutes)")
}
