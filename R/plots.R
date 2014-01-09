#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

library(ggplot2)

source(file = "R/utils.R")

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
    theme(axis.text.x=element_blank()) +
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
