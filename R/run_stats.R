plot.hist.all_files(dir = "~/Developer/pullreqs/data/")
plot.mutlicor(dfs[[12]][5:15])
plot.mutlicor(dfs[[1]][5:18], as.character(dfs[[1]]$project_name[1]))
                    
store(plot.multicor.all_dataframes, dfs, colnames(dfs[[1]]), "multicorrelations")
store(plot.hist.all_dataframes, dfs, c(5:6,8), name="foo")


plot.percentage.merged(dfs)

projects = c("metasploit-framework", "junit", "puppet", "netty", "spree")
plot.accept.lifetime.freq(dfs, projects)
plot.accept.lifetime.boxplot(dfs, projects)
plot.accept.lifetime.histogram(dfs, projects)