library(ggplot2)
library(igraph)

source(file = "R/utils.R")

# Plot a stacked barchart displaying the proportion of merged/unmerged pull requests
plot.percentage.merged <- function(dfs) 
{
  a <- do.call(rbind, Map(function(x) {
    total = nrow(x)
    merged = nrow(subset(x, merged_at > 0))
    unmerged_perc = (100 * (total - merged))/total
    merged_perc = 100 - unmerged_perc
    rbind(data.frame(project=project.name(x), status="merged", value=merged_perc),
          data.frame(project=unique(x[[1]][1]), status="unmerged", value=unmerged_perc))
  }, dfs))
  
  ggplot(a[with(a, order(status, -value)),], aes(x= project, y = value, fill = status)) + 
    geom_bar(stat="identity", colour="white") +
    theme(axis.text.x=element_text(angle=90, hjust = 1)) +
    ylab("Percentage") + 
    xlab("Project")
}

# Plot various life-time related charts for selected projects
data.merged <- function(dfs, projects, column)
{
  do.call(rbind, Map(function(x){
    project = toString(unique(x[[1]][1]))
    if (trim(project) %in% projects) {
      merged = subset(x, x$merged_at > 0)
      data.frame(name=project, id=merged$github_id, lifetime=merged[[column]])
    } else {
      data.frame(name=c(), id=c(), lifetime=c())
    }
  }, dfs)) 
}

# Plot various life-time related charts for selected projects
data.unmerged <- function(dfs, projects, column)
{
  do.call(rbind, Map(function(x){
    project = toString(unique(x[[1]][1]))
    if (trim(project) %in% projects) {
      merged = subset(x, x$merged_at == -1)
      data.frame(name=project, id=merged$github_id, lifetime=merged[[column]])
    } else {
      data.frame(name=c(), id=c(), lifetime=c())
    }
  }, dfs)) 
}

# Plot various life-time related charts for selected projects
plot.accept.lifetime.boxplot <- function(dfs, projects)
{
  ggplot(data.merged(dfs, projects, 'lifetime_minutes'), aes(factor(name), lifetime)) +
    geom_boxplot() +
    ylim(0, 3000) +
    xlab("Project") +
    ylab("Lifetime (minutes)")
}

plot.accept.lifetime.freq <- function(dfs, projects)
{
  ggplot(data.merged(dfs, projects, 'lifetime_minutes'), aes(x=lifetime, colour = name)) + 
    geom_density(alpha = 0.2) + 
    xlim(0, 10000) +
    xlab("Lifetime (minutes)") + 
    ylab("Probability")
}

plot.accept.lifetime.histogram <- function(dfs, projects)
{
  ggplot(data.merged(dfs, projects, 'lifetime_minutes'), aes(x=lifetime, fill = name)) + 
    geom_bar() +
    xlim(0, 3000) +
    xlab("Lifetime (minutes)")
}

# Plot various size-related charts for selected projects
