#
# (c) 2012 -- 2014 Georgios Gousios <gousiosg@gmail.com>
#
# BSD licensed, see LICENSE in top level dir
#

source(file = "R/packages.R")
source(file = "R/cmdline.R")

library(ggplot2)
library(grid)
library(reshape)
library(ellipse)

# Plot a list of plots using n columns
multiplot <- function(plots, cols=1, title = "") {
  require(grid)

  numPlots = length(plots)

  if (numPlots == 0){
    print("WARN: No items to be plotted")
    return
  }

  print(sprintf("Plotting %d plots using %d columns", numPlots, cols))
  layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                   ncol = cols, nrow = ceiling(numPlots/cols))

  if (numPlots==1) {
    print(plots[[1]])
  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))
    grid.text(title, gp=gpar(fontsize=12, col="grey"))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))
      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}

# Plot a histogram for var. It must exist in dataframe data.
plot.histogram <- function(data, var, title = var)
{
  print(sprintf("Plotting histogram for column %s", title))

  # Introduce some minor difference so that the data
  # gets correctly assigned to bins and plotted
  if (diff(range(data[var])) == 0) {
    print(sprintf("Fixing range for column %s", title))
    data[var][1,] <- 1
  }

  p <- ggplot(data, aes_string(x = var))
  p <- p + geom_histogram(colour="black", fill="white") + scale_x_log10()
  p <- p + ggtitle(title)
  p
}

# Plot histograms for all files/variables combinations in the provided dataframe
# Each entry in the dataframe is expected to have equal amount of columns
# Specify columns to print as a vector of column indices (c(4:7, 8)).
# By default, all columns are being printed
plot.hist.all_dataframes <- function(dfs , columns = NULL)
{

  if (! is.vector(columns)) {
    stop(print("Inputs columns is not a vector"))
  }

  cols <- colnames(dfs[[1]])[columns]
  print(sprintf("Plotting %s columns", length(cols)))

  # Create a plot per variable name for all dataframes
  lapply(cols, function(x){
      print(sprintf("Plotting column %s", x))
      items <- Filter(function(y){ x %in% colnames(y)}, dfs)

      multiplot(lapply(items, function(z){
          print(sprintf("Plotting project %s -> %s", z$project_name[[1]], x))
          plot.histogram(z, x, title = z$project_name[[1]])}),
          2, title = x)
      })
}

# Plot a multi-correlation plot for each dataframe
plot.multicor.all_dataframes <- function(dataframes, columns = NUL)
{
  for (i in 1:length(dataframes)) {
    plot.multicor(dataframes[[i]][5:18], as.character(dataframes[[i]]$project_name[1]))
  }
}
