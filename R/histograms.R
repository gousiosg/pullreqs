library(ggplot2)
library(grid)
library(reshape)
library(ellipse)

options(error=traceback)

hist_x_axis_max <- function(dfs, var) {
  # Find max value for column var across data frames
  maxval = max(unlist(Map(function(x){max(x)}, Map(function(x){x$var}, dfs))))
}

is.integer <- function(N){
  !length(grep("[^[:digit:]]", format(N, scientific = FALSE)))
}

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

# Plot a correlation matrix
plot.multicor <- function(dataframe, label = "")
{
  ctab <- cor(dataframe, method = "spearman")
  colorfun <- colorRamp(c("#CC0000","white","#3366CC"), space="Lab")
  #plotcorr(ctab, col=rgb(colorfun((ctab+1)/2), maxColorValue=255))
  plotcorr(ctab, type = "lower", xlab = label)
}

# Plot histograms for all vars in the provided dataframe
plot.hist.all_vars <- function(data, skip = 1)
{
  lapply(colnames(data)[skip:length(colnames(data))],
         function(x){plot.histogram(data, x)})
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

# Store a plot as PDF. By default, will store to user's home directory
store <- function(printer, data, cols, name, where = "~/")
{
  pdf(paste(where, paste(name, "pdf", sep=".")), width = 11.7, height = 16.5, title = name)
  printer <- match.fun(printer)
  printer(data, cols)
  dev.off()
}

# Plot a multi-correlation plot for each dataframe
plot.multicor.all_dataframes <- function(dataframes, columns = NUL)
{
  for (i in 1:length(dataframes)) {
    plot.multicor(dataframes[[i]][5:18], as.character(dataframes[[i]]$project_name[1]))
  }
}

# Load all csv files in the provided dir as data frames
load.all <- function(dir = ".") {
  lapply(list.files(path = dir, pattern = "*.csv$", full.names = T),
         function(x){read.csv(pipe(paste("cut -f2-19 -d',' ", x)))})
}

# Merge all dataframes in the provided list into one dataframe
merge.dataframes <- function(dataframes) {
  merged <- data.frame()
  for (i in 1:length(dataframes)) {
    print(sprintf("Merging dataframe %d", i))
    merged <- rbind(merged, dataframes[[i]])
  }
  merged
}
